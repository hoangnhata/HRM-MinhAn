package com.minhan.hrm.sso;

import com.minhan.hrm.dto.sso.SsoWorkforceSyncResultDto;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Date;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Set;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Đồng bộ nhân lực HRM → sso_db:
 * - Có SĐT: tạo/cập nhật UserAccounts (LoginPhone = SĐT, MK mặc định 123 khi tạo mới)
 *   + upsert EmployeePublicProfiles / EmployeePrivateProfiles
 * - Khớp TK theo mã chấm công HOẶC SĐT — 1 SĐT chỉ 1 TK; trùng thì xóa cái cũ, giữ bản HRM mới
 * - Không có SĐT: bỏ qua tạo TK (nằm danh sách cấp tài khoản mới)
 * - Sau cùng: xóa TK SSO + hồ sơ không khớp bất kỳ nhân viên HRM nào (mã chấm công / SĐT)
 */
@Slf4j
@Service
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
public class SsoWorkforceSyncService {

    private static final String DEFAULT_PASSWORD = "123";

    private final JdbcTemplate ssoJdbc;
    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;
    private final SsoRoleService ssoRoleService;
    private final ObjectProvider<SsoRelationDeptSyncService> relationDeptSync;

    /** Cache: có cột DepartmentId trên EmployeePublicProfiles hay không. */
    private Boolean publicHasDepartmentId;

    public SsoWorkforceSyncService(
            @Qualifier("ssoJdbcTemplate") JdbcTemplate ssoJdbc,
            EmployeeRepository employeeRepository,
            EmployeeWorkforceDetailsRepository workforceDetailsRepository,
            SsoRoleService ssoRoleService,
            ObjectProvider<SsoRelationDeptSyncService> relationDeptSync) {
        this.ssoJdbc = ssoJdbc;
        this.employeeRepository = employeeRepository;
        this.workforceDetailsRepository = workforceDetailsRepository;
        this.ssoRoleService = ssoRoleService;
        this.relationDeptSync = relationDeptSync;
    }

    @Transactional
    public SsoWorkforceSyncResultDto syncFromHrm() {
        Map<Long, EmployeeWorkforceDetails> workforceById = new HashMap<>();
        for (EmployeeWorkforceDetails w : workforceDetailsRepository.findAll()) {
            if (w.getEmployee() != null) {
                workforceById.put(w.getEmployeeId(), w);
            }
        }

        int scanned = 0;
        int accountsCreated = 0;
        int accountsUpdated = 0;
        int accountsDeactivated = 0;
        int duplicatesMerged = 0;
        int publicUpserted = 0;
        int privateUpserted = 0;
        int skippedNoPhone = 0;
        int skippedNoEnroll = 0;
        int skippedDuplicatePhone = 0;
        int failed = 0;
        int accountsOrphansRemoved = 0;
        int profilesOrphansRemoved = 0;
        int relationDeptCreated = 0;
        int relationDeptMatched = 0;

        SsoRelationDeptSyncService.RelationDeptCatalog deptCatalog = null;
        SsoRelationDeptSyncService deptSync = relationDeptSync.getIfAvailable();
        if (deptSync != null) {
            try {
                deptCatalog = deptSync.syncCatalogFromHrm();
                relationDeptCreated = deptCatalog.getCreated();
                relationDeptMatched = deptCatalog.getMatched();
            } catch (Exception ex) {
                log.warn("Đồng bộ RelationDept (chamcong) thất bại — tiếp tục sync NV theo tên: {}", ex.getMessage());
            }
        }

        Set<Long> hrmEnrolls = new HashSet<>();
        Set<String> hrmPhoneTails = new HashSet<>();

        // 1 SĐT → 1 nhân viên HRM (ưu tiên đang làm việc + có mã chấm công)
        Map<String, SyncTarget> byPhone = new LinkedHashMap<>();
        List<Employee> employees = employeeRepository.findAllWithDepartment();
        for (Employee emp : employees) {
            if (emp == null) {
                continue;
            }
            scanned++;
            EmployeeWorkforceDetails wf = workforceById.get(emp.getId());
            Long enroll = resolveEnroll(emp, wf);
            if (enroll == null) {
                skippedNoEnroll++;
                continue;
            }

            String loginPhone = toLoginPhone(emp.getPhone());
            if (loginPhone == null) {
                skippedNoPhone++;
                continue;
            }

            SyncTarget next = new SyncTarget(emp, wf, enroll, loginPhone);
            SyncTarget prev = byPhone.get(loginPhone);
            if (prev == null || isBetterTarget(next, prev)) {
                if (prev != null) {
                    skippedDuplicatePhone++;
                }
                byPhone.put(loginPhone, next);
            } else {
                skippedDuplicatePhone++;
            }
        }

        indexHrmWorkforceKeys(employees, workforceById, hrmEnrolls, hrmPhoneTails);

        for (SyncTarget target : byPhone.values()) {
            Employee emp = target.employee();
            EmployeeWorkforceDetails wf = target.workforce();
            long enroll = target.enroll();
            String loginPhone = target.loginPhone();

            try {
                if (emp.getStatus() == EmployeeStatus.TERMINATED) {
                    int deleted = deleteAllAccountsByPhone(loginPhone);
                    accountsDeactivated += deleted;
                    duplicatesMerged += deleted;
                    upsertPublic(emp, wf, enroll, loginPhone, false, deptCatalog);
                    publicUpserted++;
                    upsertPrivate(emp, wf, enroll);
                    privateUpserted++;
                    continue;
                }

                UpsertAccountResult upsert = upsertAccount(emp, enroll, loginPhone);
                if (upsert.created()) {
                    accountsCreated++;
                } else {
                    accountsUpdated++;
                }
                duplicatesMerged += upsert.duplicatesDeleted();
                accountsDeactivated += upsert.duplicatesDeleted();

                upsertPublic(emp, wf, enroll, loginPhone, true, deptCatalog);
                publicUpserted++;
                upsertPrivate(emp, wf, enroll);
                privateUpserted++;
            } catch (Exception ex) {
                failed++;
                log.warn("Sync SSO thất bại employeeId={}, enroll={}, phone={}: {}",
                        emp.getId(), enroll, loginPhone, ex.getMessage());
            }
        }

        try {
            accountsOrphansRemoved = purgeOrphanAccounts(hrmEnrolls, hrmPhoneTails);
            profilesOrphansRemoved = purgeOrphanProfiles(hrmEnrolls);
        } catch (Exception ex) {
            failed++;
            log.warn("Dọn TK/hồ sơ SSO lạc thất bại: {}", ex.getMessage());
        }

        String message = String.format(
                "Đồng bộ xong: quét %d NV, tạo %d TK, cập nhật %d TK, xóa trùng SĐT %d, xóa TK lạc %d, xóa hồ sơ lạc %d, public %d, private %d, RelationDept khớp %d / tạo %d, bỏ qua thiếu SĐT %d, thiếu mã CC %d, trùng SĐT HRM %d, lỗi %d",
                scanned, accountsCreated, accountsUpdated, duplicatesMerged,
                accountsOrphansRemoved, profilesOrphansRemoved,
                publicUpserted, privateUpserted, relationDeptMatched, relationDeptCreated,
                skippedNoPhone, skippedNoEnroll, skippedDuplicatePhone, failed);

        log.info(message);
        return SsoWorkforceSyncResultDto.builder()
                .scanned(scanned)
                .accountsCreated(accountsCreated)
                .accountsUpdated(accountsUpdated)
                .accountsDeactivated(accountsDeactivated)
                .duplicatesMerged(duplicatesMerged)
                .accountsOrphansRemoved(accountsOrphansRemoved)
                .profilesOrphansRemoved(profilesOrphansRemoved)
                .publicUpserted(publicUpserted)
                .privateUpserted(privateUpserted)
                .relationDeptMatched(relationDeptMatched)
                .relationDeptCreated(relationDeptCreated)
                .skippedNoPhone(skippedNoPhone)
                .skippedNoEnroll(skippedNoEnroll)
                .skippedDuplicatePhone(skippedDuplicatePhone)
                .failed(failed)
                .message(message)
                .build();
    }

    /** Mọi mã chấm công / SĐT có trong HRM — dùng đối chiếu xóa TK SSO lạc. */
    private static void indexHrmWorkforceKeys(
            List<Employee> employees,
            Map<Long, EmployeeWorkforceDetails> workforceById,
            Set<Long> hrmEnrolls,
            Set<String> hrmPhoneTails) {
        for (Employee emp : employees) {
            if (emp == null) {
                continue;
            }
            EmployeeWorkforceDetails wf = workforceById.get(emp.getId());
            Long enroll = resolveEnroll(emp, wf);
            if (enroll != null) {
                hrmEnrolls.add(enroll);
            }
            String loginPhone = toLoginPhone(emp.getPhone());
            if (loginPhone != null) {
                String tail = phoneLocal9(loginPhone);
                if (tail != null) {
                    hrmPhoneTails.add(tail);
                }
            }
            if (emp.getUser() != null && emp.getUser().getUsername() != null) {
                String fromUser = toLoginPhone(emp.getUser().getUsername());
                if (fromUser != null) {
                    String tail = phoneLocal9(fromUser);
                    if (tail != null) {
                        hrmPhoneTails.add(tail);
                    }
                }
            }
        }
    }

    /** Xóa TK SSO không khớp bất kỳ nhân viên HRM nào (theo mã chấm công hoặc SĐT). */
    private int purgeOrphanAccounts(Set<Long> hrmEnrolls, Set<String> hrmPhoneTails) {
        int removed = 0;
        for (SsoAccountRow row : listAllSsoAccounts()) {
            if (matchesHrmWorkforce(row, hrmEnrolls, hrmPhoneTails)) {
                continue;
            }
            if (deleteAccountCascade(row.accountId(), row.enroll())) {
                removed++;
                log.info("Đã xóa TK SSO lạc accountId={}, enroll={}, phone={}",
                        row.accountId(), row.enroll(), row.loginPhone());
            }
        }
        return removed;
    }

    private int purgeOrphanProfiles(Set<Long> hrmEnrolls) {
        int removed = 0;
        for (Long enroll : listAllProfileEnrolls()) {
            if (hrmEnrolls.contains(enroll)) {
                continue;
            }
            deleteProfilesByEnroll(enroll);
            removed++;
            log.info("Đã xóa hồ sơ SSO lạc enroll={}", enroll);
        }
        return removed;
    }

    private List<SsoAccountRow> listAllSsoAccounts() {
        try {
            return ssoJdbc.query(
                    "SELECT AccountId, UserEnrollNumber, LoginPhone FROM dbo.UserAccounts",
                    (rs, i) -> new SsoAccountRow(
                            rs.getLong("AccountId"),
                            rs.getObject("UserEnrollNumber") != null ? rs.getLong("UserEnrollNumber") : null,
                            rs.getString("LoginPhone")));
        } catch (DataAccessException ex) {
            log.warn("Không liệt kê được UserAccounts: {}", ex.getMessage());
            return List.of();
        }
    }

    private List<Long> listAllProfileEnrolls() {
        Set<Long> enrolls = new HashSet<>();
        try {
            ssoJdbc.query(
                    "SELECT UserEnrollNumber FROM dbo.EmployeePublicProfiles",
                    rs -> {
                        if (rs.getObject(1) != null) {
                            enrolls.add(rs.getLong(1));
                        }
                        return null;
                    });
        } catch (DataAccessException ex) {
            log.warn("Không liệt kê public profiles: {}", ex.getMessage());
        }
        try {
            ssoJdbc.query(
                    "SELECT UserEnrollNumber FROM dbo.EmployeePrivateProfiles",
                    rs -> {
                        if (rs.getObject(1) != null) {
                            enrolls.add(rs.getLong(1));
                        }
                        return null;
                    });
        } catch (DataAccessException ex) {
            log.warn("Không liệt kê private profiles: {}", ex.getMessage());
        }
        return List.copyOf(enrolls);
    }

    private static boolean matchesHrmWorkforce(
            SsoAccountRow row, Set<Long> hrmEnrolls, Set<String> hrmPhoneTails) {
        if (row.enroll() != null && hrmEnrolls.contains(row.enroll())) {
            return true;
        }
        String tail = phoneLocal9(toLoginPhone(row.loginPhone()));
        return tail != null && hrmPhoneTails.contains(tail);
    }

    private UpsertAccountResult upsertAccount(Employee emp, long enroll, String loginPhone) {
        // Ưu tiên TK đúng mã chấm công HRM; nếu không có thì tái sử dụng TK cùng SĐT rồi xóa bản cũ khác
        Long accountId = findAccountIdByEnroll(enroll);
        Long oldEnrollOnKept = null;
        if (accountId == null) {
            accountId = findAccountIdByPhone(loginPhone);
            if (accountId != null) {
                oldEnrollOnKept = findEnrollByAccountId(accountId);
            }
        }

        if (accountId == null) {
            // Xóa hết TK cũ cùng SĐT trước khi tạo bản mới từ HRM
            int deletedFirst = deleteAllAccountsByPhone(loginPhone);
            ssoJdbc.update(
                    """
                    INSERT INTO dbo.UserAccounts (
                        UserEnrollNumber, LoginPhone, Password, roles, RoleId, roleId_ts, AccountStatus
                    ) VALUES (?, ?, ?, N'guest', 1, 3, N'ACTIVE')
                    """,
                    enroll, loginPhone, DEFAULT_PASSWORD);
            accountId = findAccountIdByEnroll(enroll);
            if (accountId != null) {
                String hrmRole = resolveHrmRoleCode(emp);
                try {
                    ssoRoleService.assignHrmRole(accountId, hrmRole);
                } catch (Exception ex) {
                    log.warn("Gán role HRM thất bại accountId={}: {}", accountId, ex.getMessage());
                }
            }
            int deletedExtra = accountId != null ? deleteOtherAccountsByPhone(loginPhone, accountId, enroll) : 0;
            return new UpsertAccountResult(true, deletedFirst + deletedExtra);
        }

        ssoJdbc.update(
                """
                UPDATE dbo.UserAccounts
                SET LoginPhone = ?, UserEnrollNumber = ?, AccountStatus = N'ACTIVE', updatedAt = GETDATE()
                WHERE AccountId = ?
                """,
                loginPhone, enroll, accountId);

        // Đổi mã chấm công → xóa hồ sơ public/private gắn mã cũ
        if (oldEnrollOnKept != null && oldEnrollOnKept != enroll) {
            deleteProfilesByEnroll(oldEnrollOnKept);
        }

        int deleted = deleteOtherAccountsByPhone(loginPhone, accountId, enroll);
        return new UpsertAccountResult(false, deleted);
    }

    /** Xóa mọi TK cùng SĐT (NV nghỉ việc hoặc trước khi tạo mới). */
    private int deleteAllAccountsByPhone(String loginPhone) {
        List<AccountRef> refs = findAccountsByPhone(loginPhone, null);
        int n = 0;
        for (AccountRef ref : refs) {
            if (deleteAccountCascade(ref.accountId(), ref.enroll())) {
                n++;
            }
        }
        return n;
    }

    /**
     * Xóa các TK trùng SĐT (cũ), giữ lại keepAccountId / mã chấm công HRM mới.
     */
    private int deleteOtherAccountsByPhone(String loginPhone, long keepAccountId, long keepEnroll) {
        List<AccountRef> refs = findAccountsByPhone(loginPhone, keepAccountId);
        int n = 0;
        for (AccountRef ref : refs) {
            if (ref.accountId() == keepAccountId) {
                continue;
            }
            if (deleteAccountCascade(ref.accountId(), ref.enroll())) {
                n++;
            }
            // Hồ sơ gắn mã cũ khác mã HRM hiện tại
            if (ref.enroll() != null && ref.enroll() != keepEnroll) {
                deleteProfilesByEnroll(ref.enroll());
            }
        }
        return n;
    }

    private boolean deleteAccountCascade(long accountId, Long enroll) {
        try {
            ssoJdbc.update("DELETE FROM dbo.UserAppRoles WHERE AccountId = ?", accountId);
            int n = ssoJdbc.update("DELETE FROM dbo.UserAccounts WHERE AccountId = ?", accountId);
            if (enroll != null) {
                // Không xóa profile nếu vẫn còn TK khác dùng cùng enroll (hiếm)
                Integer stillUsed = ssoJdbc.query(
                        "SELECT TOP 1 1 FROM dbo.UserAccounts WHERE UserEnrollNumber = ?",
                        rs -> rs.next() ? 1 : null,
                        enroll);
                if (stillUsed == null) {
                    deleteProfilesByEnroll(enroll);
                }
            }
            return n > 0;
        } catch (DataAccessException ex) {
            log.warn("Xóa TK SSO AccountId={} thất bại: {}", accountId, ex.getMessage());
            // Fallback: khóa nếu không xóa được do FK lạ
            ssoJdbc.update(
                    """
                    UPDATE dbo.UserAccounts
                    SET AccountStatus = N'INACTIVE', updatedAt = GETDATE()
                    WHERE AccountId = ?
                    """,
                    accountId);
            return true;
        }
    }

    private void deleteProfilesByEnroll(long enroll) {
        try {
            ssoJdbc.update("DELETE FROM dbo.EmployeePublicProfiles WHERE UserEnrollNumber = ?", enroll);
        } catch (DataAccessException ex) {
            log.warn("Xóa public profile enroll={} thất bại: {}", enroll, ex.getMessage());
        }
        try {
            ssoJdbc.update("DELETE FROM dbo.EmployeePrivateProfiles WHERE UserEnrollNumber = ?", enroll);
        } catch (DataAccessException ex) {
            log.warn("Xóa private profile enroll={} thất bại: {}", enroll, ex.getMessage());
        }
    }

    private List<AccountRef> findAccountsByPhone(String loginPhone, Long exceptAccountId) {
        String local9 = phoneLocal9(loginPhone);
        if (local9 == null) {
            return List.of();
        }
        try {
            return ssoJdbc.query(
                    """
                    SELECT AccountId, UserEnrollNumber FROM dbo.UserAccounts
                    WHERE (
                           LoginPhone = ?
                        OR LoginPhone = ?
                        OR RIGHT(REPLACE(REPLACE(LoginPhone, '+', ''), ' ', ''), 9) = ?
                      )
                      AND (? IS NULL OR AccountId <> ?)
                    """,
                    (rs, i) -> new AccountRef(
                            rs.getLong("AccountId"),
                            rs.getObject("UserEnrollNumber") != null ? rs.getLong("UserEnrollNumber") : null),
                    loginPhone,
                    "0" + local9,
                    local9,
                    exceptAccountId,
                    exceptAccountId);
        } catch (DataAccessException ex) {
            return List.of();
        }
    }

    private Long findEnrollByAccountId(long accountId) {
        try {
            return ssoJdbc.query(
                    "SELECT TOP 1 UserEnrollNumber FROM dbo.UserAccounts WHERE AccountId = ?",
                    rs -> rs.next() && rs.getObject(1) != null ? rs.getLong(1) : null,
                    accountId);
        } catch (DataAccessException ex) {
            return null;
        }
    }

    private void upsertPublic(
            Employee emp,
            EmployeeWorkforceDetails wf,
            long enroll,
            String loginPhone,
            boolean active,
            SsoRelationDeptSyncService.RelationDeptCatalog deptCatalog) {
        String fullName = nullToEmpty(emp.getFullName());
        if (fullName.isBlank()) {
            fullName = "NV-" + enroll;
        }
        String hrmDepartmentName = emp.getDepartment() != null ? emp.getDepartment().getName() : null;
        String workUnit = wf != null ? blankToNull(wf.getWorkUnitDetail()) : null;

        Integer departmentId = null;
        String departmentName = workUnit != null ? workUnit : hrmDepartmentName;
        String subDepartmentName = hrmDepartmentName;

        if (deptCatalog != null) {
            Long hrmDeptId = emp.getDepartment() != null ? emp.getDepartment().getId() : null;
            SsoRelationDeptSyncService.ResolvedDept resolved =
                    deptCatalog.resolve(hrmDeptId, hrmDepartmentName, workUnit);
            if (resolved != null) {
                departmentId = resolved.id();
                if (resolved.description() != null && !resolved.description().isBlank()) {
                    // Giữ đúng tên trên RelationDept (SSO) để các app khác nhận diện
                    departmentName = resolved.description();
                }
            }
        }
        if (departmentName == null) {
            departmentName = hrmDepartmentName;
        }

        String position = emp.getPosition() != null ? emp.getPosition().getTitle() : null;
        String publicStatus = active ? "Đang làm việc" : "Nghỉ việc";
        String payrollName = wf != null && wf.getPayrollDisplayName() != null
                ? wf.getPayrollDisplayName()
                : fullName;
        LocalDate official = wf != null ? wf.getOfficialStartDate() : null;
        if (official == null && emp.getStatus() == EmployeeStatus.ACTIVE) {
            official = emp.getHireDate();
        }

        Integer exists = ssoJdbc.query(
                "SELECT TOP 1 1 FROM dbo.EmployeePublicProfiles WHERE UserEnrollNumber = ?",
                rs -> rs.next() ? 1 : null,
                enroll);

        boolean writeDeptId = departmentId != null && hasPublicDepartmentIdColumn();

        if (exists == null) {
            if (writeDeptId) {
                ssoJdbc.update(
                        """
                        INSERT INTO dbo.EmployeePublicProfiles (
                            UserEnrollNumber, UserFullName, Phone, Email, DOB,
                            DepartmentId, DepartmentName, PublicStatus, CCCD, EmployeeCode, PayrollName,
                            Gender, Address, WorkPosition, Specialty, Degree,
                            SubDepartmentName, OfficialStartDate, ProfessionalDegree, PracticeScope,
                            createdAt, updatedAt
                        ) VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE())
                        """,
                        enroll,
                        fullName,
                        loginPhone,
                        toSqlDate(emp.getDateOfBirth()),
                        departmentId,
                        departmentName,
                        publicStatus,
                        blankToNull(emp.getIdCardNumber()),
                        blankToNull(emp.getEmployeeCode()),
                        payrollName,
                        blankToNull(emp.getGender()),
                        blankToNull(emp.getAddress()),
                        blankToNull(position),
                        wf != null ? blankToNull(wf.getSpecialty()) : null,
                        wf != null ? blankToNull(wf.getDegree()) : null,
                        blankToNull(subDepartmentName),
                        toSqlDate(official),
                        wf != null ? blankToNull(wf.getProfessionalDiploma()) : null,
                        wf != null ? blankToNull(wf.getPracticeScope()) : null);
            } else {
                ssoJdbc.update(
                        """
                        INSERT INTO dbo.EmployeePublicProfiles (
                            UserEnrollNumber, UserFullName, Phone, Email, DOB,
                            DepartmentName, PublicStatus, CCCD, EmployeeCode, PayrollName,
                            Gender, Address, WorkPosition, Specialty, Degree,
                            SubDepartmentName, OfficialStartDate, ProfessionalDegree, PracticeScope,
                            createdAt, updatedAt
                        ) VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE())
                        """,
                        enroll,
                        fullName,
                        loginPhone,
                        toSqlDate(emp.getDateOfBirth()),
                        departmentName,
                        publicStatus,
                        blankToNull(emp.getIdCardNumber()),
                        blankToNull(emp.getEmployeeCode()),
                        payrollName,
                        blankToNull(emp.getGender()),
                        blankToNull(emp.getAddress()),
                        blankToNull(position),
                        wf != null ? blankToNull(wf.getSpecialty()) : null,
                        wf != null ? blankToNull(wf.getDegree()) : null,
                        blankToNull(subDepartmentName),
                        toSqlDate(official),
                        wf != null ? blankToNull(wf.getProfessionalDiploma()) : null,
                        wf != null ? blankToNull(wf.getPracticeScope()) : null);
            }
            return;
        }

        if (writeDeptId) {
            ssoJdbc.update(
                    """
                    UPDATE dbo.EmployeePublicProfiles SET
                        UserFullName = ?, Phone = ?, DOB = ?,
                        DepartmentId = ?, DepartmentName = ?, PublicStatus = ?, CCCD = ?, EmployeeCode = ?, PayrollName = ?,
                        Gender = ?, Address = ?, WorkPosition = ?, Specialty = ?, Degree = ?,
                        SubDepartmentName = ?, OfficialStartDate = ?, ProfessionalDegree = ?, PracticeScope = ?,
                        updatedAt = GETDATE()
                    WHERE UserEnrollNumber = ?
                    """,
                    fullName,
                    loginPhone,
                    toSqlDate(emp.getDateOfBirth()),
                    departmentId,
                    departmentName,
                    publicStatus,
                    blankToNull(emp.getIdCardNumber()),
                    blankToNull(emp.getEmployeeCode()),
                    payrollName,
                    blankToNull(emp.getGender()),
                    blankToNull(emp.getAddress()),
                    blankToNull(position),
                    wf != null ? blankToNull(wf.getSpecialty()) : null,
                    wf != null ? blankToNull(wf.getDegree()) : null,
                    blankToNull(subDepartmentName),
                    toSqlDate(official),
                    wf != null ? blankToNull(wf.getProfessionalDiploma()) : null,
                    wf != null ? blankToNull(wf.getPracticeScope()) : null,
                    enroll);
        } else {
            ssoJdbc.update(
                    """
                    UPDATE dbo.EmployeePublicProfiles SET
                        UserFullName = ?, Phone = ?, DOB = ?,
                        DepartmentName = ?, PublicStatus = ?, CCCD = ?, EmployeeCode = ?, PayrollName = ?,
                        Gender = ?, Address = ?, WorkPosition = ?, Specialty = ?, Degree = ?,
                        SubDepartmentName = ?, OfficialStartDate = ?, ProfessionalDegree = ?, PracticeScope = ?,
                        updatedAt = GETDATE()
                    WHERE UserEnrollNumber = ?
                    """,
                    fullName,
                    loginPhone,
                    toSqlDate(emp.getDateOfBirth()),
                    departmentName,
                    publicStatus,
                    blankToNull(emp.getIdCardNumber()),
                    blankToNull(emp.getEmployeeCode()),
                    payrollName,
                    blankToNull(emp.getGender()),
                    blankToNull(emp.getAddress()),
                    blankToNull(position),
                    wf != null ? blankToNull(wf.getSpecialty()) : null,
                    wf != null ? blankToNull(wf.getDegree()) : null,
                    blankToNull(subDepartmentName),
                    toSqlDate(official),
                    wf != null ? blankToNull(wf.getProfessionalDiploma()) : null,
                    wf != null ? blankToNull(wf.getPracticeScope()) : null,
                    enroll);
        }
    }

    private boolean hasPublicDepartmentIdColumn() {
        if (publicHasDepartmentId != null) {
            return publicHasDepartmentId;
        }
        try {
            Integer n = ssoJdbc.query(
                    """
                    SELECT TOP 1 1 FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'EmployeePublicProfiles' AND COLUMN_NAME = 'DepartmentId'
                    """,
                    rs -> rs.next() ? 1 : null);
            publicHasDepartmentId = n != null;
        } catch (DataAccessException ex) {
            publicHasDepartmentId = false;
        }
        return publicHasDepartmentId;
    }

    private void upsertPrivate(Employee emp, EmployeeWorkforceDetails wf, long enroll) {
        Integer exists = ssoJdbc.query(
                "SELECT TOP 1 1 FROM dbo.EmployeePrivateProfiles WHERE UserEnrollNumber = ?",
                rs -> rs.next() ? 1 : null,
                enroll);

        LocalDate certDate = null;
        if (wf != null && wf.getPracticeCertDateRaw() != null) {
            certDate = tryParseDate(wf.getPracticeCertDateRaw());
        }

        if (exists == null) {
            ssoJdbc.update(
                    """
                    INSERT INTO dbo.EmployeePrivateProfiles (
                        UserEnrollNumber, CCCD, CCCDIssueDate, PayrollBankAccount, PayrollBankName,
                        InsuranceParticipation, PersonnelNote, ProbationStartDate,
                        ContractNumber, ContractSignDate, ContractTerm, OfficialDuration, Seniority,
                        SocialInsuranceNumber, PracticeCertificateNumber, PracticeCertificateIssueDate,
                        OtherTrainingCertificates, CKI, DependentInformation,
                        createdAt, updatedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, SYSDATETIME(), SYSDATETIME())
                    """,
                    enroll,
                    blankToNull(emp.getIdCardNumber()),
                    wf != null ? toSqlDate(wf.getIdCardIssueDate()) : null,
                    wf != null ? blankToNull(wf.getBankAccount()) : null,
                    wf != null ? blankToNull(wf.getBankName()) : null,
                    wf != null ? blankToNull(wf.getInsuranceParticipation()) : null,
                    wf != null ? blankToNull(wf.getWorkforceNotes()) : null,
                    wf != null ? toSqlDate(wf.getProbationStartDate()) : null,
                    wf != null ? blankToNull(wf.getContractNumber()) : null,
                    wf != null ? toSqlDate(wf.getContractSignDate()) : null,
                    wf != null ? blankToNull(wf.getContractTerm()) : null,
                    wf != null ? blankToNull(wf.getTenureText()) : null,
                    wf != null ? blankToNull(wf.getSocialInsuranceBook()) : null,
                    wf != null ? blankToNull(wf.getPracticeCertNumber()) : null,
                    toSqlDate(certDate),
                    wf != null ? blankToNull(wf.getOtherTrainingCertificates()) : null,
                    wf != null ? blankToNull(wf.getCki()) : null,
                    wf != null ? blankToNull(wf.getDependentsInfo()) : null);
            return;
        }

        ssoJdbc.update(
                """
                UPDATE dbo.EmployeePrivateProfiles SET
                    CCCD = ?, CCCDIssueDate = ?, PayrollBankAccount = ?, PayrollBankName = ?,
                    InsuranceParticipation = ?, PersonnelNote = ?, ProbationStartDate = ?,
                    ContractNumber = ?, ContractSignDate = ?, ContractTerm = ?, Seniority = ?,
                    SocialInsuranceNumber = ?, PracticeCertificateNumber = ?, PracticeCertificateIssueDate = ?,
                    OtherTrainingCertificates = ?, CKI = ?, DependentInformation = ?,
                    updatedAt = SYSDATETIME()
                WHERE UserEnrollNumber = ?
                """,
                blankToNull(emp.getIdCardNumber()),
                wf != null ? toSqlDate(wf.getIdCardIssueDate()) : null,
                wf != null ? blankToNull(wf.getBankAccount()) : null,
                wf != null ? blankToNull(wf.getBankName()) : null,
                wf != null ? blankToNull(wf.getInsuranceParticipation()) : null,
                wf != null ? blankToNull(wf.getWorkforceNotes()) : null,
                wf != null ? toSqlDate(wf.getProbationStartDate()) : null,
                wf != null ? blankToNull(wf.getContractNumber()) : null,
                wf != null ? toSqlDate(wf.getContractSignDate()) : null,
                wf != null ? blankToNull(wf.getContractTerm()) : null,
                wf != null ? blankToNull(wf.getTenureText()) : null,
                wf != null ? blankToNull(wf.getSocialInsuranceBook()) : null,
                wf != null ? blankToNull(wf.getPracticeCertNumber()) : null,
                toSqlDate(certDate),
                wf != null ? blankToNull(wf.getOtherTrainingCertificates()) : null,
                wf != null ? blankToNull(wf.getCki()) : null,
                wf != null ? blankToNull(wf.getDependentsInfo()) : null,
                enroll);
    }

    private Long findAccountIdByEnroll(long enroll) {
        try {
            return ssoJdbc.query(
                    "SELECT TOP 1 AccountId FROM dbo.UserAccounts WHERE UserEnrollNumber = ?",
                    rs -> rs.next() ? rs.getLong(1) : null,
                    enroll);
        } catch (DataAccessException ex) {
            return null;
        }
    }

    private Long findAccountIdByPhone(String loginPhone) {
        String local9 = phoneLocal9(loginPhone);
        if (local9 == null) {
            return null;
        }
        try {
            return ssoJdbc.query(
                    """
                    SELECT TOP 1 AccountId FROM dbo.UserAccounts
                    WHERE LoginPhone = ?
                       OR LoginPhone = ?
                       OR RIGHT(REPLACE(REPLACE(LoginPhone, '+', ''), ' ', ''), 9) = ?
                    ORDER BY
                        CASE WHEN AccountStatus = N'ACTIVE' THEN 0 ELSE 1 END,
                        AccountId ASC
                    """,
                    rs -> rs.next() ? rs.getLong(1) : null,
                    loginPhone,
                    "0" + local9,
                    local9);
        } catch (DataAccessException ex) {
            return null;
        }
    }

    private static boolean isBetterTarget(SyncTarget next, SyncTarget prev) {
        boolean nextActive = next.employee().getStatus() != EmployeeStatus.TERMINATED;
        boolean prevActive = prev.employee().getStatus() != EmployeeStatus.TERMINATED;
        if (nextActive != prevActive) {
            return nextActive;
        }
        boolean nextHasAtt = next.workforce() != null
                && next.workforce().getAttendanceCode() != null
                && !next.workforce().getAttendanceCode().isBlank();
        boolean prevHasAtt = prev.workforce() != null
                && prev.workforce().getAttendanceCode() != null
                && !prev.workforce().getAttendanceCode().isBlank();
        if (nextHasAtt != prevHasAtt) {
            return nextHasAtt;
        }
        // Ưu tiên mã chấm công dài hơn (thường là mã máy mới), tránh giữ mã cũ ngắn
        return String.valueOf(next.enroll()).length() > String.valueOf(prev.enroll()).length();
    }

    private static Long resolveEnroll(Employee emp, EmployeeWorkforceDetails wf) {
        return SsoEnrollResolver.resolveEnroll(emp, wf);
    }

    private static String resolveHrmRoleCode(Employee emp) {
        if (emp.getUser() != null && emp.getUser().getRole() != null) {
            UserRole r = emp.getUser().getRole();
            return r.name();
        }
        return "EMPLOYEE";
    }

    private static Long parseLong(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            String digits = raw.trim().replaceAll("\\D", "");
            if (digits.isEmpty()) {
                return null;
            }
            String normalized = digits.replaceFirst("^0+(?!$)", "");
            return Long.parseLong(normalized.isEmpty() ? "0" : normalized);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    static String toLoginPhone(String rawPhone) {
        if (rawPhone == null || rawPhone.isBlank()) {
            return null;
        }
        String digits = rawPhone.replaceAll("\\D", "");
        if (digits.isEmpty()) {
            return null;
        }
        if (digits.startsWith("0") && digits.length() >= 10) {
            return "84" + digits.substring(1);
        }
        if (digits.startsWith("84") && digits.length() >= 11) {
            return digits;
        }
        if (digits.length() < 9) {
            return null;
        }
        return digits;
    }

    private static String phoneLocal9(String loginPhone) {
        if (loginPhone == null || loginPhone.isBlank()) {
            return null;
        }
        String digits = loginPhone.replaceAll("\\D", "");
        if (digits.length() < 9) {
            return null;
        }
        return digits.substring(digits.length() - 9);
    }

    private static Date toSqlDate(LocalDate d) {
        return d != null ? Date.valueOf(d) : null;
    }

    private static LocalDate tryParseDate(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String s = raw.trim();
        try {
            if (s.matches("\\d{4}-\\d{2}-\\d{2}.*")) {
                return LocalDate.parse(s.substring(0, 10));
            }
            if (s.matches("\\d{1,2}/\\d{1,2}/\\d{4}")) {
                String[] p = s.split("/");
                return LocalDate.of(Integer.parseInt(p[2]), Integer.parseInt(p[1]), Integer.parseInt(p[0]));
            }
        } catch (Exception ignored) {
            // ignore
        }
        return null;
    }

    private static String blankToNull(String s) {
        return s != null && !s.isBlank() ? s.trim() : null;
    }

    private static String nullToEmpty(String s) {
        return s == null ? "" : s.trim();
    }

    private record SyncTarget(Employee employee, EmployeeWorkforceDetails workforce, long enroll, String loginPhone) {}

    private record UpsertAccountResult(boolean created, int duplicatesDeleted) {}

    private record AccountRef(long accountId, Long enroll) {}

    private record SsoAccountRow(long accountId, Long enroll, String loginPhone) {}
}
