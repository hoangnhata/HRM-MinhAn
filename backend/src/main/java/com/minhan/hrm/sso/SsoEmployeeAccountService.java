package com.minhan.hrm.sso;

import com.minhan.hrm.dto.sso.AccountGrantRequest;
import com.minhan.hrm.dto.sso.AccountGrantResponse;
import com.minhan.hrm.dto.sso.EmployeeAccountCandidateDto;
import com.minhan.hrm.dto.sso.EmployeeAccountCandidatePageDto;
import com.minhan.hrm.dto.sso.SsoHrmRoleDto;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import lombok.extern.slf4j.Slf4j;
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
    private final SsoRoleService ssoRoleService;

    public SsoEmployeeAccountService(
            @Qualifier("ssoJdbcTemplate") JdbcTemplate ssoJdbc,
            EmployeeRepository employeeRepository,
            EmployeeWorkforceDetailsRepository workforceDetailsRepository,
            SsoRoleService ssoRoleService) {
        this.ssoJdbc = ssoJdbc;
        this.employeeRepository = employeeRepository;
        this.workforceDetailsRepository = workforceDetailsRepository;
        this.ssoRoleService = ssoRoleService;
    }

    @Transactional(readOnly = true)
    public EmployeeAccountCandidatePageDto listEmployeesWithoutAccount(
            String search, Integer page, Integer limit, String dept) {
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
            Long accountIdentifier = resolveAccountIdentifier(emp, attendanceCode);
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
            all.add(EmployeeAccountCandidateDto.builder()
                    .id(accountIdentifier)
                    .name(emp.getFullName())
                    .dept(departmentName)
                    .phone(emp.getPhone())
                    .cccd(emp.getIdCardNumber())
                    .roleId(null)
                    .roleIdTs(null)
                    .build());
        }

        all.sort(Comparator.comparing(
                EmployeeAccountCandidateDto::getName, Comparator.nullsLast(String::compareToIgnoreCase)));

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

        Integer existing = ssoJdbc.query(
                "SELECT TOP 1 1 FROM dbo.UserAccounts WHERE UserEnrollNumber = ?",
                rs -> rs.next() ? 1 : null,
                userEnrollNumber);
        if (existing != null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Nhân viên này đã có tài khoản đăng nhập");
        }

        Employee employee = findEmployeeForProvisioning(userEnrollNumber)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "Không tìm thấy hồ sơ nhân viên để cấp tài khoản"));
        String resolvedAttendanceCode = resolveAttendanceCodeForProvisioning(employee);
        Long resolvedUserEnrollNumber = resolveAccountIdentifier(employee, resolvedAttendanceCode);
        if (resolvedUserEnrollNumber == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy mã chấm công để cấp tài khoản");
        }
        Employee emp = employee;
        String loginPhone = toLoginPhone(emp != null ? emp.getPhone() : null);

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

        log.info(
                "Đã cấp tài khoản đăng nhập HRM cho UserEnrollNumber={}, hrmRole={}",
                resolvedUserEnrollNumber,
                hrmRoleCode);
        return AccountGrantResponse.builder()
                .message("Cấp tài khoản đăng nhập thành công")
                .id(String.valueOf(resolvedUserEnrollNumber))
                .build();
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

    private static Long parseEnrollNumber(String attendanceCode) {
        if (attendanceCode == null || attendanceCode.isBlank()) {
            return null;
        }
        try {
            return Long.parseLong(attendanceCode.trim());
        } catch (NumberFormatException e) {
            return null;
        }
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
                        resolveAccountIdentifier(
                                emp,
                                workforceByEmployeeId.containsKey(emp.getId())
                                        ? workforceByEmployeeId.get(emp.getId()).getAttendanceCode()
                                        : null),
                        identifier))
                .findFirst();
    }

    private String resolveAttendanceCodeForProvisioning(Employee employee) {
        if (employee == null) {
            return null;
        }
        return workforceDetailsRepository.findByEmployee(employee)
                .map(EmployeeWorkforceDetails::getAttendanceCode)
                .orElse(null);
    }

    private static Long resolveAccountIdentifier(Employee employee, String attendanceCode) {
        Long fromAttendance = parseEnrollNumber(attendanceCode);
        if (fromAttendance != null) {
            return fromAttendance;
        }
        return employee != null ? parseEnrollNumber(employee.getEmployeeCode()) : null;
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
            String foldedName = fold(employee.getFullName());
            return !foldedName.isBlank() && nameKeySet.contains(foldedName);
        }
    }
}
