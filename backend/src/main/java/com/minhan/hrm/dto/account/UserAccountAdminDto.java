package com.minhan.hrm.dto.account;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class UserAccountAdminDto {
    Long userId;
    String username;
    String email;
    String displayName;
    String role;
    boolean enabled;
    boolean directorApprovalEnabled;
    /** Được xem báo cáo nhân lực (cấp bởi Admin). */
    boolean reportViewEnabled;
    /** true = được xuất Excel báo cáo công (cấp bởi Admin). */
    boolean attendanceExcelExportEnabled;
    /** true = xem hồ sơ NV toàn viện, không gồm lương (cấp bởi Admin). */
    boolean hospitalWideEmployeeViewEnabled;
    /** true = xem báo cáo Trình độ chuyên môn (cấp bởi Admin). */
    boolean professionalQualificationReportEnabled;
    /**
     * Phân quyền công: chỉ cần chấm vào sáng và ra chiều để đủ công cả ngày
     * (lưu trên hồ sơ NV — {@code employees.continuous_shift}).
     */
    boolean twoPunchAttendance;
    /** Trưởng khoa chỉ quản lý bộ phận của mình (không cả khoa). */
    boolean workUnitScoped;
    boolean mustChangePassword;
    boolean hasSignature;
    Long employeeId;
    String employeeCode;
    String fullName;
    String phone;
    String attendanceCode;
    Long departmentId;
    String departmentName;
    String workUnitDetail;
    String positionTitle;
}
