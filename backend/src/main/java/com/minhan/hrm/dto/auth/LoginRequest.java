package com.minhan.hrm.dto.auth;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LoginRequest {

    @NotBlank
    private String username;

    @NotBlank
    private String password;

    /**
     * App di động gửi {@code true} để nhận refresh token (giữ đăng nhập tới khi tự đăng xuất).
     * Web không gửi → chỉ nhận access token 8 giờ như trước.
     */
    private Boolean rememberDevice;

    /** Tên thiết bị hiển thị cho quản trị (vd. "iPhone 15 · iOS 18"), tuỳ chọn. */
    private String deviceLabel;
}
