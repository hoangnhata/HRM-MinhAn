package com.minhan.hrm.dto.account;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class AccountMeResponse {
    Long userId;
    String username;
    String email;
    /** Vai trò HRM (SSO UserAppRoles) — không lấy từ ERP roles. */
    String role;
    String fullName;
    Long employeeId;
    boolean enabled;
    boolean mustChangePassword;
    String createdAt;
    String phone;
    String address;
    String departmentName;
    Long departmentId;
    /** true khi đã liên kết token ERP và lấy được hồ sơ từ ERP */
    boolean erpLinked;
    /** Ngày sinh (yyyy-MM-dd) từ ERP */
    String dateOfBirth;
    String userAvatar;
    Integer userEnrollNumber;
}
