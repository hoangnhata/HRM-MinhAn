package com.minhan.hrm.sso;

import com.minhan.hrm.dto.sso.AccountGrantRequest;
import com.minhan.hrm.dto.sso.AccountGrantResponse;
import com.minhan.hrm.dto.sso.EmployeeAccountCandidateDto;
import com.minhan.hrm.dto.sso.EmployeeAccountCandidatePageDto;
import com.minhan.hrm.dto.sso.SsoHrmRoleDto;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.entity.EmploymentType;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;

/**
 * Cấp tài khoản đăng nhập HRM cho nhân viên chưa có tài khoản trên sso_db.
 * Nguồn nhân viên: HRM (employees + employee_workforce_details.attendance_code = UserEnrollNumber).
 * Không đụng cột legacy UserAccounts.roles / RoleId ngoài việc set giá trị khi tạo mới.
 */
@Slf4j
@Service
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
public class SsoEmployeeAccountService {

    private static final Set<Integer> VALID_HR_ROLE_IDS = Set.of(1, 2, 3);
    private static final Set<Integer> VALID_ASSET_ROLE_IDS = Set.of(1, 2, 3, 4);
    private static final int DEFAULT_LIMIT = 100;
    private static final int MAX_LIMIT = 200;

    private final JdbcTemplate ssoJdbc;
    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;
    private final UserAccountRepository userAccountRepository;
    private final SsoRoleService ssoRoleService;
    private final ObjectProvider<SsoRelationDeptSyncService> relationDeptSync;
    private Boolean publicHasDepartmentId;

    public SsoEmployeeAccountService(
            @Qualifier("ssoJdbcTemplate") JdbcTemplate ssoJdbc,
            EmployeeRepository employeeRepository,
            EmployeeWorkforceDetailsRepository workforceDetailsRepository,
            UserAccountRepository userAccountRepository,
            SsoRoleService ssoRoleService,
            ObjectProvider<SsoRelationDeptSyncService> relationDeptSync) {
        this.ssoJdbc = ssoJdbc;
        this.employeeRepository = employeeRepository;
        this.workforceDetailsRepository = workforceDetailsRepository;
        this.userAccountRepository = userAccountRepository;
        this.ssoRoleService = ssoRoleService;
        this.relationDeptSync = relationDeptSync;
    }

    @Transactional(readOnly = true)
    public EmployeeAccountCandidatePageDto listEmployeesWithoutAccount(
            String search, Integer page, Integer limit, String dept, String trialGroup) {
        int safePage = page != null && page > 0 ? page : 1;
        int safeLimit = limit != null && limit > 0 ? Math.min(limit, MAX_LIMIT) : DEFAULT_LIMIT;

        String qFold = fold(search);
        String deptFold = fold(dept);
        ExistingSsoAccounts existingSsoAccounts = loadExistingSsoAccounts();

        Map<Long, EmployeeWorkforceDetails> workforceByEmployeeId = new HashMap<>();
        for (EmployeeWorkforceDetails workforce : workforceDetailsRepository.findAll()) {
            if (workforce.getEmployee() != null) {
                workforceByEmployeeId.put(workforce.getEmployeeId(), workforce);
            }
        }

        List<EmployeeAccountCandidateDto> all = new ArrayList<>();
        for (Employee emp : employeeRepository.findAllWithDepartment()) {
            if (emp == null || emp.getStatus() == EmployeeStatus.TERMINATED) {
                continue;
            }
            EmployeeWorkforceDetails workforce = workforceByEmployeeId.get(emp.getId());
            String attendanceCode = workforce != null ? workforce.getAttendanceCode() : null;
            Long accountIdentifier = SsoEnrollResolver.resolveGrantListIdentifier(emp, attendanceCode);
            if (accountIdentifier == null) {
                continue;
            }
            if (existingSsoAccounts.matches(emp, attendanceCode)) {
                continue;
            }
            String departmentName = emp.getDepartment() != null ? emp.getDepartment().getName() : null;
            if (!deptFold.isEmpty() && !fold(departmentName).contains(deptFold)) {
                continue;
            }
            if (!qFold.isEmpty() && !matchesSearch(qFold, emp, attendanceCode, departmentName)) {
                continue;
            }
            if (!matchesTrialGroupFilter(emp, trialGroup)) {
                continue;
            }
            boolean missingPhone = toLoginPhone(emp.getPhone()) == null;
            boolean missingAttendanceCode = attendanceCode == null || attendanceCode.isBlank();
            all.add(EmployeeAccountCandidateDto.builder()
                    .id(accountIdentifier)
                    .hrmEmployeeId(emp.getId())
                    .employeeCode(emp.getEmployeeCode())
                    .employeeStatus(emp.getStatus() != null ? emp.getStatus().name() : null)
                    .employmentType(emp.getEmploymentType() != null ? emp.getEmploymentType().name() : EmploymentType.FULL_TIME.name())
                    .attendanceCode(attendanceCode)
                    .missingAttendanceCode(missingAttendanceCode)
                    .name(emp.getFullName())
                    .dept(departmentName)
                    .phone(emp.getPhone())
                    .cccd(emp.getIdCardNumber())
                    .missingPhone(missingPhone)
                    .roleId(null)
                    .roleIdTs(null)
                    .build());
        }

        all.sort(Comparator
                .comparing((EmployeeAccountCandidateDto c) -> !Boolean.TRUE.equals(c.getMissingPhone()))
                .thenComparing(c -> !SsoEnrollResolver.isTrialEmployeeStatus(c.getEmployeeStatus()))
                .thenComparing(EmployeeAccountCandidateDto::getName, Comparator.nullsLast(String::compareToIgnoreCase)));

        int total = all.size();
        int from = Math.min((safePage - 1) * safeLimit, total);
        int to = Math.min(from + safeLimit, total);
        List<EmployeeAccountCandidateDto> pageData = all.subList(from, to);

        return EmployeeAccountCandidatePageDto.builder()
                .total(total)
                .page(safePage)
                .limit(safeLimit)
                .data(pageData)
                .build();
    }

    @Transactional
    public AccountGrantResponse grantAccount(long userEnrollNumber, AccountGrantRequest req) {
        int roleId = req.getRoleId() != null ? req.getRoleId() : 1;
        int roleIdTs = req.getRoleIdTs() != null ? req.getRoleIdTs() : 3;
        String hrmRoleCode = req.getHrmRoleCode() != null && !req.getHrmRoleCode().isBlank()
                ? req.getHrmRoleCode().trim()
                : "EMPLOYEE";
        String password = req.getPassword() != null && !req.getPassword().isBlank()
                ? req.getPassword().trim()
                : "123";

        if (!VALID_HR_ROLE_IDS.contains(roleId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Vai trò ERP không hợp lệ");
        }
        if (!VALID_ASSET_ROLE_IDS.contains(roleIdTs)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Vai trò Tài sản không hợp lệ");
        }
        try {
            SsoUserRoleMapper.toUserRole(hrmRoleCode);
        } catch (ApiException ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chức danh HRM không hợp lệ");
        }

        Integer existingByEnroll = ssoJdbc.query(
                "SELECT TOP 1 1 FROM dbo.UserAccounts WHERE UserEnrollNumber = ?",
                rs -> rs.next() ? 1 : null,
                userEnrollNumber);
        if (existingByEnroll != null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Nhân viên này đã có tài khoản đăng nhập");
        }

        Employee employee = findEmployeeForProvisioning(userEnrollNumber)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "Không tìm thấy hồ sơ nhân viên để cấp tài khoản"));
        Employee emp = employee;

        // Cho phép nhập SĐT khi cấp TK: lưu vào HRM rồi dùng làm tài khoản đăng nhập
        String requestedPhone = req.getPhone() != null ? req.getPhone().trim() : null;
        if (requestedPhone != null && !requestedPhone.isBlank()) {
            String normalizedLogin = toLoginPhone(requestedPhone);
            if (normalizedLogin == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Số điện thoại không hợp lệ. Nhập SĐT 10 số (vd: 0912345678)");
            }
            String hrmPhone = toHrmDisplayPhone(requestedPhone);
            emp.setPhone(hrmPhone);
            employeeRepository.save(emp);
        }

        String requestedAttendanceCode = req.getAttendanceCode() != null ? req.getAttendanceCode().trim() : null;
        if (requestedAttendanceCode != null && !requestedAttendanceCode.isBlank()) {
            upsertAttendanceCode(emp, requestedAttendanceCode);
        } else {
            String existingCode = resolveAttendanceCodeForProvisioning(emp);
            if (existingCode == null || existingCode.isBlank()) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Nhập mã chấm công — lưu vào HRM để NV xem được số công và đăng nhập SSO");
            }
        }

        String resolvedAttendanceCode = resolveAttendanceCodeForProvisioning(emp);
        Long resolvedUserEnrollNumber = SsoEnrollResolver.resolveAccountIdentifier(emp, resolvedAttendanceCode);
        if (resolvedUserEnrollNumber == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mã chấm công không hợp lệ");
        }

        if (!Objects.equals(resolvedUserEnrollNumber, userEnrollNumber)) {
            Integer existingResolved = ssoJdbc.query(
                    "SELECT TOP 1 1 FROM dbo.UserAccounts WHERE UserEnrollNumber = ?",
                    rs -> rs.next() ? 1 : null,
                    resolvedUserEnrollNumber);
            if (existingResolved != null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Mã chấm công này đã có tài khoản đăng nhập trên SSO");
            }
        }

        String loginPhone = toLoginPhone(emp.getPhone());
        if (loginPhone == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên chưa có số điện thoại. Nhập SĐT khi cấp tài khoản để lưu vào hồ sơ HRM");
        }

        // 1 SĐT = 1 TK — không cấp trùng dù khác mã chấm công
        String local9 = loginPhone.length() >= 9 ? loginPhone.substring(loginPhone.length() - 9) : loginPhone;
        Integer existingByPhone = ssoJdbc.query(
                """
                SELECT TOP 1 1 FROM dbo.UserAccounts
                WHERE AccountStatus = N'ACTIVE'
                  AND (
                       LoginPhone = ?
                    OR LoginPhone = ?
                    OR RIGHT(REPLACE(REPLACE(LoginPhone, '+', ''), ' ', ''), 9) = ?
                  )
                """,
                rs -> rs.next() ? 1 : null,
                loginPhone,
                "0" + local9,
                local9);
        if (existingByPhone != null) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Số điện thoại này đã có tài khoản đăng nhập. Mỗi SĐT chỉ được 1 tài khoản");
        }

        syncHrmUserLoginAfterGrant(emp, loginPhone, hrmRoleCode);

        try {
            ssoJdbc.update(
                    """
                    INSERT INTO dbo.UserAccounts (
                        UserEnrollNumber, LoginPhone, Password, roles, RoleId, roleId_ts, AccountStatus
                    ) VALUES (?, ?, ?, N'guest', ?, ?, N'ACTIVE')
                    """,
                    resolvedUserEnrollNumber, loginPhone, password, roleId, roleIdTs);
        } catch (DataAccessException ex) {
            log.error("Lỗi cấp tài khoản đăng nhập cho UserEnrollNumber={}", userEnrollNumber, ex);
            throw new ApiException(
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "Lỗi khi cấp tài khoản đăng nhập: " + rootMessage(ex));
        }

        Long accountId = ssoJdbc.query(
                "SELECT TOP 1 AccountId FROM dbo.UserAccounts WHERE UserEnrollNumber = ?",
                rs -> rs.next() ? rs.getLong(1) : null,
                resolvedUserEnrollNumber);
        if (accountId != null) {
            ssoRoleService.assignHrmRole(accountId, hrmRoleCode);
        }

        // Đồng bộ luôn hồ sơ public/private sau khi cấp TK
        try {
            syncProfilesAfterGrant(emp, resolvedUserEnrollNumber, loginPhone);
        } catch (Exception ex) {
            log.warn("Cấp TK OK nhưng sync hồ sơ SSO lỗi enroll={}: {}", resolvedUserEnrollNumber, ex.getMessage());
        }

        log.info(
                "Đã cấp tài khoản đăng nhập HRM cho UserEnrollNumber={}, loginPhone={}, hrmRole={}",
                resolvedUserEnrollNumber,
                loginPhone,
                hrmRoleCode);
        return AccountGrantResponse.builder()
                .message("Cấp tài khoản thành công — SĐT = tài khoản, mã chấm công "
                        + resolvedAttendanceCode + " (UserEnrollNumber " + resolvedUserEnrollNumber + ")")
                .id(String.valueOf(resolvedUserEnrollNumber))
                .build();
    }

    private void syncHrmUserLoginAfterGrant(Employee emp, String loginPhone, String hrmRoleCode) {
        UserRole role = SsoUserRoleMapper.toUserRole(hrmRoleCode);
        UserAccount linked = emp.getUser();
        Optional<UserAccount> phoneUserOpt = userAccountRepository.findByUsername(loginPhone);

        if (phoneUserOpt.isPresent()) {
            UserAccount phoneUser = phoneUserOpt.get();
            employeeRepository.findByUser(phoneUser).ifPresent(other -> {
                if (!other.getId().equals(emp.getId())) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "SĐT đã gắn hồ sơ nhân viên khác");
                }
            });
            if (linked != null && !phoneUser.getId().equals(linked.getId())) {
                emp.setUser(phoneUser);
                employeeRepository.save(emp);
                linked.setEnabled(false);
                userAccountRepository.save(linked);
            } else if (linked == null) {
                emp.setUser(phoneUser);
                employeeRepository.save(emp);
            }
            phoneUser.setRole(role);
            phoneUser.setEnabled(true);
            userAccountRepository.save(phoneUser);
            return;
        }

        if (linked != null) {
            linked.setUsername(loginPhone);
            linked.setRole(role);
            linked.setEnabled(true);
            userAccountRepository.save(linked);
        }
    }

    private void upsertAttendanceCode(Employee emp, String code) {
        String trimmed = code.trim();
        if (trimmed.isEmpty()) {
            return;
        }
        workforceDetailsRepository.findByAttendanceCode(trimmed).ifPresent(other -> {
            if (!other.getEmployeeId().equals(emp.getId())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Mã chấm công đã gắn với nhân viên khác");
            }
        });
        EmployeeWorkforceDetails wf = workforceDetailsRepository.findByEmployee(emp)
                .orElse(EmployeeWorkforceDetails.builder().employee(emp).build());
        wf.setAttendanceCode(trimmed);
        workforceDetailsRepository.save(wf);
    }

    private static boolean matchesTrialGroupFilter(Employee emp, String trialGroup) {
        if (trialGroup == null || trialGroup.isBlank()) {
            return true;
        }
        boolean trial = SsoEnrollResolver.isTrialEmployee(emp);
        EmploymentType type = emp.getEmploymentType() != null ? emp.getEmploymentType() : EmploymentType.FULL_TIME;
        String g = trialGroup.trim().toUpperCase(Locale.ROOT);
        // Tương thích bản cũ (đã bỏ — thử việc không chia TTG/BTG)
        if ("TRIAL_TTG".equals(g) || "TRIAL_BTG".equals(g)) {
            g = "TRIAL";
        }
        return switch (g) {
            case "TRIAL" -> trial;
            case "OFFICIAL" -> !trial;
            case "OFFICIAL_TTG" -> !trial && type == EmploymentType.FULL_TIME;
            case "OFFICIAL_BTG" -> !trial && type == EmploymentType.PART_TIME;
            default -> true;
        };
    }

    private void syncProfilesAfterGrant(Employee emp, long enroll, String loginPhone) {
        EmployeeWorkforceDetails wf = workforceDetailsRepository.findByEmployee(emp).orElse(null);
        String fullName = emp.getFullName() != null ? emp.getFullName().trim() : ("NV-" + enroll);
        String hrmDepartmentName = emp.getDepartment() != null ? emp.getDepartment().getName() : null;
        String workUnit = wf != null && wf.getWorkUnitDetail() != null && !wf.getWorkUnitDetail().isBlank()
                ? wf.getWorkUnitDetail().trim()
                : null;
        String departmentName = workUnit != null ? workUnit : hrmDepartmentName;
        Integer departmentId = null;

        SsoRelationDeptSyncService deptSync = relationDeptSync.getIfAvailable();
        if (deptSync != null) {
            try {
                SsoRelationDeptSyncService.RelationDeptCatalog catalog = deptSync.syncCatalogFromHrm();
                Long hrmDeptId = emp.getDepartment() != null ? emp.getDepartment().getId() : null;
                SsoRelationDeptSyncService.ResolvedDept resolved =
                        catalog.resolve(hrmDeptId, hrmDepartmentName, workUnit);
                if (resolved != null) {
                    departmentId = resolved.id();
                    if (resolved.description() != null && !resolved.description().isBlank()) {
                        departmentName = resolved.description();
                    }
                }
            } catch (Exception ex) {
                log.warn("Grant account: không khớp RelationDept cho enroll={}: {}", enroll, ex.getMessage());
            }
        }

        String position = emp.getPosition() != null ? emp.getPosition().getTitle() : null;
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
                            UserEnrollNumber, UserFullName, Phone, DepartmentId, DepartmentName, PublicStatus,
                            CCCD, EmployeeCode, PayrollName, Gender, Address, WorkPosition, SubDepartmentName,
                            createdAt, updatedAt
                        ) VALUES (?, ?, ?, ?, ?, N'Đang làm việc', ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE())
                        """,
                        enroll, fullName, loginPhone, departmentId, departmentName,
                        emp.getIdCardNumber(), emp.getEmployeeCode(),
                        wf != null && wf.getPayrollDisplayName() != null ? wf.getPayrollDisplayName() : fullName,
                        emp.getGender(), emp.getAddress(), position, hrmDepartmentName);
            } else {
                ssoJdbc.update(
                        """
                        INSERT INTO dbo.EmployeePublicProfiles (
                            UserEnrollNumber, UserFullName, Phone, DepartmentName, PublicStatus,
                            CCCD, EmployeeCode, PayrollName, Gender, Address, WorkPosition, SubDepartmentName,
                            createdAt, updatedAt
                        ) VALUES (?, ?, ?, ?, N'Đang làm việc', ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE())
                        """,
                        enroll, fullName, loginPhone, departmentName,
                        emp.getIdCardNumber(), emp.getEmployeeCode(),
                        wf != null && wf.getPayrollDisplayName() != null ? wf.getPayrollDisplayName() : fullName,
                        emp.getGender(), emp.getAddress(), position, hrmDepartmentName);
            }
        } else if (writeDeptId) {
            ssoJdbc.update(
                    """
                    UPDATE dbo.EmployeePublicProfiles SET
                        UserFullName = ?, Phone = ?, DepartmentId = ?, DepartmentName = ?,
                        PublicStatus = N'Đang làm việc',
                        CCCD = ?, EmployeeCode = ?, Gender = ?, Address = ?, WorkPosition = ?,
                        SubDepartmentName = ?, updatedAt = GETDATE()
                    WHERE UserEnrollNumber = ?
                    """,
                    fullName, loginPhone, departmentId, departmentName,
                    emp.getIdCardNumber(), emp.getEmployeeCode(),
                    emp.getGender(), emp.getAddress(), position, hrmDepartmentName, enroll);
        } else {
            ssoJdbc.update(
                    """
                    UPDATE dbo.EmployeePublicProfiles SET
                        UserFullName = ?, Phone = ?, DepartmentName = ?, PublicStatus = N'Đang làm việc',
                        CCCD = ?, EmployeeCode = ?, Gender = ?, Address = ?, WorkPosition = ?,
                        SubDepartmentName = ?, updatedAt = GETDATE()
                    WHERE UserEnrollNumber = ?
                    """,
                    fullName, loginPhone, departmentName,
                    emp.getIdCardNumber(), emp.getEmployeeCode(),
                    emp.getGender(), emp.getAddress(), position, hrmDepartmentName, enroll);
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

    private ExistingSsoAccounts loadExistingSsoAccounts() {
        List<SsoHrmRoleDto> rows = ssoRoleService.listHrmAccounts(null);
        Map<Long, String> displayNames = ssoRoleService.loadAccountDisplayNames();
        Set<String> enrollKeys = new HashSet<>();
        Set<String> phoneKeys = new HashSet<>();
        Set<String> nameKeys = new HashSet<>();

        for (SsoHrmRoleDto row : rows) {
            if (row.getUserEnrollNumber() != null) {
                enrollKeys.addAll(enrollKeys(String.valueOf(row.getUserEnrollNumber())));
            }
            phoneKeys.addAll(phoneKeys(row.getLoginPhone()));
            String displayName = displayNames.get(row.getAccountId());
            if (displayName != null && !displayName.isBlank()) {
                nameKeys.add(fold(displayName));
            }
        }

        return new ExistingSsoAccounts(enrollKeys, phoneKeys, nameKeys);
    }

    private String resolveAttendanceCodeForProvisioning(Employee employee) {
        if (employee == null) {
            return null;
        }
        return workforceDetailsRepository.findByEmployee(employee)
                .map(EmployeeWorkforceDetails::getAttendanceCode)
                .orElse(null);
    }

    private Optional<Employee> findEmployeeForProvisioning(long identifier) {
        Map<Long, EmployeeWorkforceDetails> workforceByEmployeeId = new HashMap<>();
        for (EmployeeWorkforceDetails workforce : workforceDetailsRepository.findAll()) {
            if (workforce.getEmployee() != null) {
                workforceByEmployeeId.put(workforce.getEmployeeId(), workforce);
            }
        }
        return employeeRepository.findAllWithDepartment().stream()
                .filter(emp -> emp.getStatus() != EmployeeStatus.TERMINATED)
                .filter(emp -> Objects.equals(
                        SsoEnrollResolver.resolveGrantListIdentifier(
                                emp,
                                workforceByEmployeeId.containsKey(emp.getId())
                                        ? workforceByEmployeeId.get(emp.getId()).getAttendanceCode()
                                        : null),
                        identifier))
                .findFirst();
    }

    private static Set<String> enrollKeys(String code) {
        Set<String> keys = new LinkedHashSet<>();
        if (code == null || code.isBlank()) {
            return keys;
        }
        String trimmed = code.trim();
        keys.add(trimmed);
        keys.add(trimmed.toLowerCase(Locale.ROOT));
        String digits = trimmed.replaceAll("\\D", "");
        if (!digits.isEmpty()) {
            String normalized = digits.replaceFirst("^0+(?!$)", "");
            String key = normalized.isEmpty() ? "0" : normalized;
            keys.add(digits);
            keys.add(key);
            if (key.length() <= 6) {
                keys.add(String.format("%04d", Integer.parseInt(key)));
                keys.add(String.format("%05d", Integer.parseInt(key)));
                keys.add(String.format("%06d", Integer.parseInt(key)));
            }
        }
        return keys;
    }

    private static Set<String> phoneKeys(String rawPhone) {
        Set<String> keys = new LinkedHashSet<>();
        if (rawPhone == null || rawPhone.isBlank()) {
            return keys;
        }
        String digits = rawPhone.replaceAll("\\D", "");
        if (digits.isEmpty()) {
            return keys;
        }
        keys.add(digits);
        if (digits.startsWith("84") && digits.length() >= 11) {
            keys.add("0" + digits.substring(2));
        }
        if (digits.startsWith("0") && digits.length() >= 10) {
            keys.add("84" + digits.substring(1));
        }
        if (digits.length() >= 9) {
            keys.add(digits.substring(digits.length() - 9));
        }
        return keys;
    }

    private static boolean matchesSearch(String qFold, Employee emp, String attendanceCode, String departmentName) {
        return contains(fold(emp.getFullName()), qFold)
                || contains(fold(emp.getIdCardNumber()), qFold)
                || contains(fold(emp.getPhone()), qFold)
                || contains(fold(emp.getEmployeeCode()), qFold)
                || contains(fold(attendanceCode), qFold)
                || contains(fold(departmentName), qFold);
    }

    private static boolean contains(String haystack, String needle) {
        return haystack != null && needle != null && haystack.contains(needle);
    }

    private static String toLoginPhone(String rawPhone) {
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

    /** Chuẩn hóa SĐT lưu trên HRM dạng 0xxxxxxxxx. */
    private static String toHrmDisplayPhone(String rawPhone) {
        String digits = rawPhone == null ? "" : rawPhone.replaceAll("\\D", "");
        if (digits.isEmpty()) {
            return rawPhone != null ? rawPhone.trim() : null;
        }
        if (digits.startsWith("84") && digits.length() >= 11) {
            return "0" + digits.substring(2);
        }
        if (digits.startsWith("0")) {
            return digits;
        }
        if (digits.length() == 9) {
            return "0" + digits;
        }
        return digits;
    }

    private static String rootMessage(Throwable ex) {
        Throwable t = ex;
        while (t.getCause() != null) {
            t = t.getCause();
        }
        return t.getMessage() != null ? t.getMessage() : ex.getMessage();
    }

    private static String fold(String s) {
        if (s == null) {
            return "";
        }
        String n = Normalizer.normalize(s, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.ROOT)
                .replace('đ', 'd');
        return n.trim();
    }

    private record ExistingSsoAccounts(
            Set<String> enrolledKeySet,
            Set<String> phoneKeySet,
            Set<String> nameKeySet) {

        boolean matches(Employee employee, String attendanceCode) {
            if (employee == null) {
                return false;
            }
            Long resolvedEnroll = SsoEnrollResolver.resolveAccountIdentifier(employee, attendanceCode);
            if (resolvedEnroll != null && enrolledKeySet.contains(String.valueOf(resolvedEnroll))) {
                return true;
            }
            if (attendanceCode != null && enrolledKeySet.stream().anyMatch(enrollKeys(attendanceCode)::contains)) {
                return true;
            }
            if (employee.getEmployeeCode() != null
                    && enrolledKeySet.stream().anyMatch(enrollKeys(employee.getEmployeeCode())::contains)) {
                return true;
            }
            if (employee.getPhone() != null && phoneKeySet.stream().anyMatch(phoneKeys(employee.getPhone())::contains)) {
                return true;
            }
            return false;
        }
    }
}
