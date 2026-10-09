package com.minhan.hrm.dto.auth;

import com.minhan.hrm.entity.UserRole;
import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class LoginResponse {
    String accessToken;
    /** Chỉ có khi đăng nhập từ app với {@code rememberDevice = true} hoặc khi làm mới phiên. */
    String refreshToken;
    String tokenType;
    UserRole role;
    Long userId;
    Long employeeId;
    String fullName;
    String email;
    boolean mustChangePassword;
    /** true khi chưa có chữ ký số — bắt buộc tạo ở lần đăng nhập đầu */
    boolean mustSetSignature;
}
