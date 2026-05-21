package com.minhan.hrm.dto.auth;

import com.minhan.hrm.entity.UserRole;
import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class LoginResponse {
    String accessToken;
    String tokenType;
    UserRole role;
    Long userId;
    Long employeeId;
    String fullName;
    String email;
}
