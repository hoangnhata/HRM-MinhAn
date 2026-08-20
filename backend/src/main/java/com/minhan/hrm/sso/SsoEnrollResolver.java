package com.minhan.hrm.sso;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;

import java.util.Locale;

/** Chuẩn hóa UserEnrollNumber (mã chấm công SSO) từ hồ sơ HRM — gồm NV thử việc TV-. */
public final class SsoEnrollResolver {

    /** NV thử việc chưa có mã số — offset tránh trùng mã máy chấm công thật. */
    public static final long TRIAL_ENROLL_OFFSET = 8_000_000L;
    /** NV chính thức chưa có mã chấm công / mã số — dùng tạm trên danh sách cấp TK. */
    public static final long OFFICIAL_PENDING_ENROLL_OFFSET = 9_000_000L;

    private SsoEnrollResolver() {
    }

    public static boolean isTrialEmployee(Employee employee) {
        if (employee == null) {
            return false;
        }
        if (employee.getStatus() == EmployeeStatus.PROBATION || employee.getStatus() == EmployeeStatus.INTERN) {
            return true;
        }
        String code = employee.getEmployeeCode();
        return code != null && code.toUpperCase(Locale.ROOT).startsWith("TV-");
    }

    public static Long parseNumericEnroll(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String trimmed = raw.trim();
        try {
            return Long.parseLong(trimmed);
        } catch (NumberFormatException ignored) {
            // TV-15071990, mã có chữ…
        }
        String digits = trimmed.replaceAll("\\D", "");
        if (digits.isEmpty()) {
            return null;
        }
        try {
            String normalized = digits.replaceFirst("^0+(?!$)", "");
            return Long.parseLong(normalized.isEmpty() ? "0" : normalized);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public static Long resolveAccountIdentifier(Employee employee, String attendanceCode) {
        Long fromAttendance = parseNumericEnroll(attendanceCode);
        if (fromAttendance != null) {
            return fromAttendance;
        }
        if (employee == null) {
            return null;
        }
        Long fromCode = parseNumericEnroll(employee.getEmployeeCode());
        if (fromCode != null) {
            return fromCode;
        }
        if (isTrialEmployee(employee) && employee.getId() != null) {
            return TRIAL_ENROLL_OFFSET + employee.getId();
        }
        return null;
    }

    /** Id hiển thị trên danh sách «Cấp tài khoản» — gồm NV chính thức chưa có mã chấm công. */
    public static Long resolveGrantListIdentifier(Employee employee, String attendanceCode) {
        Long resolved = resolveAccountIdentifier(employee, attendanceCode);
        if (resolved != null) {
            return resolved;
        }
        if (isGrantEligibleOfficial(employee) && employee.getId() != null) {
            return OFFICIAL_PENDING_ENROLL_OFFSET + employee.getId();
        }
        return null;
    }

    public static boolean isTrialEmployeeStatus(String status) {
        return "PROBATION".equals(status) || "INTERN".equals(status);
    }

    public static Long resolveEnroll(Employee employee, EmployeeWorkforceDetails workforce) {
        if (workforce != null) {
            Long fromAtt = parseNumericEnroll(workforce.getAttendanceCode());
            if (fromAtt != null) {
                return fromAtt;
            }
        }
        return resolveAccountIdentifier(employee, null);
    }

    /** NV chính thức (không thử việc) — còn ACTIVE / ON_LEAVE / … */
    public static boolean isGrantEligibleOfficial(Employee employee) {
        if (employee == null || isTrialEmployee(employee)) {
            return false;
        }
        EmployeeStatus status = employee.getStatus();
        return status != null && status != EmployeeStatus.TERMINATED;
    }
}
