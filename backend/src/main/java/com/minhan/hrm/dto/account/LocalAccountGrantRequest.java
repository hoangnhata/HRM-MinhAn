package com.minhan.hrm.dto.account;

import com.minhan.hrm.entity.UserRole;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class LocalAccountGrantRequest {
    @NotNull
    private Long employeeId;
    private UserRole role;
    /** Nếu trống → mật khẩu mặc định import (123) + bắt đổi lần đầu */
    private String password;
    /** SĐT đăng nhập — bắt buộc nếu hồ sơ chưa có SĐT */
    private String phone;
    /** Mã chấm công máy */
    private String attendanceCode;
}
