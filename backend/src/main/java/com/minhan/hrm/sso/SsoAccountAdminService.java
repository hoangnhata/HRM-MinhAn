package com.minhan.hrm.sso;

import com.minhan.hrm.dto.sso.SsoAccountAdminRowDto;
import com.minhan.hrm.dto.sso.SsoHrmRoleDto;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
public class SsoAccountAdminService {

    private final SsoRoleService ssoRoleService;
    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;
    private final UserAccountRepository userAccountRepository;
    private final SsoRoleSyncService ssoRoleSyncService;

    @Transactional(readOnly = true)
    public List<SsoAccountAdminRowDto> listAccounts(String q, Long departmentId) {
        List<SsoHrmRoleDto> rows = ssoRoleService.listHrmAccounts(null);
        Map<String, Employee> byPhoneTail = indexEmployeesByPhoneTail();
        Map<String, Employee> byEnroll = indexEmployeesByEnroll();
        Map<String, String> displayByPhoneTail = indexDisplayNamesByPhoneTail();
        Map<Long, String> ssoDisplayNames = ssoRoleService.loadAccountDisplayNames();

        String qLower = q != null ? q.trim().toLowerCase(Locale.ROOT) : "";

        return rows.stream()
                .flatMap(r -> {
                    Employee emp = matchEmployee(r, byPhoneTail, byEnroll);
                    if (departmentId != null) {
                        if (emp == null || emp.getDepartment() == null
                                || !departmentId.equals(emp.getDepartment().getId())) {
                            return java.util.stream.Stream.empty();
                        }
                    }
                    String fullName = resolveFullName(r, emp, displayByPhoneTail, ssoDisplayNames);
                    String roleName = r.getRoleName() != null ? r.getRoleName() : roleLabelVi(r.getRoleCode());
                    SsoAccountAdminRowDto row = SsoAccountAdminRowDto.builder()
                            .accountId(r.getAccountId())
                            .loginPhone(r.getLoginPhone())
                            .userEnrollNumber(r.getUserEnrollNumber())
                            .roleCode(r.getRoleCode())
                            .roleName(roleName)
                            .fullName(fullName)
                            .departmentName(emp != null && emp.getDepartment() != null
                                    ? emp.getDepartment().getName() : null)
                            .hrmEmployeeId(emp != null ? emp.getId() : null)
                            .build();
                    return java.util.stream.Stream.of(row);
                })
                .filter(row -> {
                    if (qLower.isEmpty()) {
                        return true;
                    }
                    return contains(row.getFullName(), qLower)
                            || matchesPhone(row.getLoginPhone(), qLower)
                            || (row.getUserEnrollNumber() != null
                            && String.valueOf(row.getUserEnrollNumber()).contains(qLower));
                })
                .toList();
    }

    @Transactional
    public SsoHrmRoleDto assignAndSync(long accountId, String roleCode) {
        SsoHrmRoleDto assigned = ssoRoleService.assignHrmRole(accountId, roleCode);
        if (assigned.getLoginPhone() != null) {
            try {
                ssoRoleSyncService.syncHrmRoleByLoginPhone(assigned.getLoginPhone());
            } catch (Exception ignored) {
                // SSO đã cập nhật; HRM có thể chưa có user khớp SĐT
            }
        }
        return assigned;
    }

    private static String resolveFullName(
            SsoHrmRoleDto row,
            Employee emp,
            Map<String, String> displayByPhoneTail,
            Map<Long, String> ssoDisplayNames) {
        if (emp != null && emp.getFullName() != null && !emp.getFullName().isBlank()) {
            return emp.getFullName();
        }
        String fromLocal = matchDisplayName(row.getLoginPhone(), displayByPhoneTail);
        if (fromLocal != null) {
            return fromLocal;
        }
        String fromSso = ssoDisplayNames.get(row.getAccountId());
        if (fromSso != null && !fromSso.isBlank()) {
            return fromSso;
        }
        return null;
    }

    private Map<String, Employee> indexEmployeesByPhoneTail() {
        Map<String, Employee> map = new HashMap<>();
        for (Employee e : employeeRepository.findAll()) {
            indexPhoneVariants(map, e.getPhone(), e);
            if (e.getUser() != null) {
                indexPhoneVariants(map, e.getUser().getUsername(), e);
            }
            if (e.getDepartment() != null) {
                e.getDepartment().getName();
            }
        }
        return map;
    }

    private Map<String, Employee> indexEmployeesByEnroll() {
        Map<String, Employee> map = new HashMap<>();
        for (Employee e : employeeRepository.findAll()) {
            if (e.getDepartment() != null) {
                e.getDepartment().getName();
            }
            putEnrollKeys(map, e.getEmployeeCode(), e);
        }
        for (EmployeeWorkforceDetails w : workforceDetailsRepository.findAllWithAttendanceCodeAndEmployee()) {
            Employee e = w.getEmployee();
            if (e == null) {
                continue;
            }
            if (e.getDepartment() != null) {
                e.getDepartment().getName();
            }
            putEnrollKeys(map, w.getAttendanceCode(), e);
        }
        return map;
    }

    private static void putEnrollKeys(Map<String, Employee> map, String code, Employee employee) {
        if (code == null || code.isBlank() || employee == null) {
            return;
        }
        for (String key : enrollKeys(code)) {
            map.putIfAbsent(key, employee);
        }
    }

    /** Các dạng khóa mã chấm công để khớp SSO ↔ HRM. */
    private static Set<String> enrollKeys(String code) {
        Set<String> keys = new LinkedHashSet<>();
        String trimmed = code.trim();
        keys.add(trimmed);
        keys.add(trimmed.toLowerCase(Locale.ROOT));
        String digits = trimmed.replaceAll("\\D", "");
        if (!digits.isEmpty()) {
            String normalized = normalizeEnrollKey(digits);
            keys.add(normalized);
            keys.add(digits);
            // zero-pad thường gặp trên máy chấm công
            if (normalized.length() <= 6) {
                keys.add(String.format("%04d", Integer.parseInt(normalized)));
                keys.add(String.format("%05d", Integer.parseInt(normalized)));
                keys.add(String.format("%06d", Integer.parseInt(normalized)));
            }
        }
        return keys;
    }

    private static Employee matchEmployee(
            SsoHrmRoleDto row,
            Map<String, Employee> byPhoneTail,
            Map<String, Employee> byEnroll) {
        boolean phoneOk = isLikelyPhone(row.getLoginPhone());

        if (phoneOk) {
            Employee byPhone = matchEmployeeByPhone(row.getLoginPhone(), byPhoneTail);
            if (byPhone != null) {
                return byPhone;
            }
        }

        Employee enrolled = matchEmployeeByEnroll(row, byEnroll);
        if (enrolled != null) {
            return enrolled;
        }

        // SĐT không chuẩn (hoặc chính là mã chấm công) — thử thêm 1 lần theo phone tail
        if (!phoneOk) {
            return matchEmployeeByPhone(row.getLoginPhone(), byPhoneTail);
        }
        return null;
    }

    private static Employee matchEmployeeByEnroll(SsoHrmRoleDto row, Map<String, Employee> byEnroll) {
        if (row.getUserEnrollNumber() != null) {
            Employee e = lookupEnroll(byEnroll, String.valueOf(row.getUserEnrollNumber()));
            if (e != null) {
                return e;
            }
        }
        // LoginPhone trên SSO đôi khi lưu mã chấm công thay vì SĐT
        if (row.getLoginPhone() != null && !row.getLoginPhone().isBlank()) {
            String digits = row.getLoginPhone().replaceAll("\\D", "");
            if (!digits.isEmpty() && !isLikelyPhone(row.getLoginPhone())) {
                return lookupEnroll(byEnroll, digits);
            }
        }
        return null;
    }

    private static Employee lookupEnroll(Map<String, Employee> byEnroll, String code) {
        for (String key : enrollKeys(code)) {
            Employee e = byEnroll.get(key);
            if (e != null) {
                return e;
            }
        }
        return null;
    }

    /** SĐT VN hợp lệ (đủ dài); số ngắn kiểu 2003/6001 coi là mã chấm công. */
    private static boolean isLikelyPhone(String raw) {
        if (raw == null || raw.isBlank()) {
            return false;
        }
        String digits = raw.replaceAll("\\D", "");
        if (digits.length() < 9) {
            return false;
        }
        if (digits.startsWith("84") && digits.length() >= 11) {
            return true;
        }
        if (digits.startsWith("0") && digits.length() >= 10) {
            return true;
        }
        // 9 số cuối kiểu di động VN (3xx…9xx)
        char first = digits.charAt(digits.length() - 9);
        return first >= '3' && first <= '9';
    }

    private Map<String, String> indexDisplayNamesByPhoneTail() {
        Map<String, String> map = new HashMap<>();
        for (UserAccount user : userAccountRepository.findAll()) {
            if (user.getDisplayName() == null || user.getDisplayName().isBlank()) {
                continue;
            }
            indexDisplayPhoneVariants(map, user.getUsername(), user.getDisplayName());
        }
        return map;
    }

    private static void indexPhoneVariants(Map<String, Employee> map, String raw, Employee employee) {
        for (String candidate : phoneCandidates(raw)) {
            String tail = phoneTail(candidate);
            if (tail != null) {
                map.putIfAbsent(tail, employee);
            }
        }
    }

    private static void indexDisplayPhoneVariants(Map<String, String> map, String raw, String displayName) {
        for (String candidate : phoneCandidates(raw)) {
            String tail = phoneTail(candidate);
            if (tail != null) {
                map.putIfAbsent(tail, displayName);
            }
        }
    }

    private static String matchDisplayName(String loginPhone, Map<String, String> byTail) {
        for (String candidate : phoneCandidates(loginPhone)) {
            String tail = phoneTail(candidate);
            if (tail != null) {
                String name = byTail.get(tail);
                if (name != null && !name.isBlank()) {
                    return name;
                }
            }
        }
        return null;
    }

    private static Set<String> phoneCandidates(String raw) {
        Set<String> out = new LinkedHashSet<>();
        if (raw == null || raw.isBlank()) {
            return out;
        }
        out.add(raw.trim());
        String digits = raw.replaceAll("\\D", "");
        if (!digits.isEmpty()) {
            out.add(digits);
            out.add(toErpLoginPhone(raw));
            if (digits.startsWith("84") && digits.length() >= 11) {
                out.add("0" + digits.substring(2));
            }
            if (digits.startsWith("0") && digits.length() >= 10) {
                out.add("84" + digits.substring(1));
            }
        }
        return out;
    }

    private static boolean contains(String value, String qLower) {
        return value != null && value.toLowerCase(Locale.ROOT).contains(qLower);
    }

    /** Khớp SĐT dạng 0xxx, 84xxx hoặc 9 số cuối. */
    private static boolean matchesPhone(String loginPhone, String qLower) {
        if (loginPhone == null || loginPhone.isBlank()) {
            return false;
        }
        if (contains(loginPhone, qLower)) {
            return true;
        }
        String qDigits = qLower.replaceAll("\\D", "");
        if (qDigits.isEmpty()) {
            return false;
        }
        String phoneDigits = loginPhone.replaceAll("\\D", "");
        if (phoneDigits.contains(qDigits)) {
            return true;
        }
        if (qDigits.length() >= 9 && phoneDigits.length() >= 9) {
            return phoneDigits.endsWith(qDigits.substring(qDigits.length() - 9))
                    || qDigits.endsWith(phoneDigits.substring(phoneDigits.length() - 9));
        }
        return false;
    }

    private static Employee matchEmployeeByPhone(String loginPhone, Map<String, Employee> byTail) {
        for (String candidate : phoneCandidates(loginPhone)) {
            String tail = phoneTail(candidate);
            if (tail != null) {
                Employee emp = byTail.get(tail);
                if (emp != null) {
                    return emp;
                }
            }
        }
        return null;
    }

    private static String phoneTail(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String digits = raw.replaceAll("\\D", "");
        if (digits.length() < 9) {
            return null;
        }
        return digits.substring(digits.length() - 9);
    }

    private static String normalizeEnrollKey(String code) {
        String digits = code.replaceAll("\\D", "");
        if (digits.isEmpty()) {
            return code.trim();
        }
        String trimmed = digits.replaceFirst("^0+(?!$)", "");
        return trimmed.isEmpty() ? "0" : trimmed;
    }

    private static String toErpLoginPhone(String raw) {
        String digits = raw.replaceAll("\\D", "");
        if (digits.startsWith("0") && digits.length() >= 10) {
            return "84" + digits.substring(1);
        }
        return digits.isEmpty() ? raw.trim() : digits;
    }

    private static String roleLabelVi(String code) {
        if (code == null) {
            return "Chưa gán";
        }
        return switch (code) {
            case "ADMIN" -> "Quản trị hệ thống";
            case "EMPLOYEE" -> "Nhân viên";
            case "HR" -> "Hành chính nhân sự";
            case "HEAD_DEPARTMENT" -> "Trưởng khoa / phòng";
            case "HEAD_NURSING" -> "Điều dưỡng trưởng";
            case "DIRECTOR" -> "Giám đốc";
            default -> code;
        };
    }
}
