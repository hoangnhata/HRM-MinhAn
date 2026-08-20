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
