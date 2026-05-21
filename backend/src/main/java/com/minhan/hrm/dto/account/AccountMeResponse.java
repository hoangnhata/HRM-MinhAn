package com.minhan.hrm.dto.account;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class AccountMeResponse {
    Long userId;
    String username;
    String email;
    String role;
    String fullName;
    Long employeeId;
    boolean enabled;
    String createdAt;
    /** Khi có hồ sơ NV */
    String phone;
    String address;
    String departmentName;
    Long departmentId;
}
