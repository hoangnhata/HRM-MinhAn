package com.minhan.hrm.dto.employee;

import com.minhan.hrm.entity.UserRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class EmployeeCreateRequest {

    @NotNull
    private UserRole role;

    @Email
    @NotBlank
    private String email;

    /** Bắt buộc với EMPLOYEE — dùng làm username đăng nhập. */
    private String phone;

    /** Chỉ dùng khi tạo tài khoản quản lý (HR / trưởng khoa / ĐD trưởng). */
    private String username;
    private String password;

    @NotBlank
    private String fullName;

    private String idCardNumber;
    private LocalDate dateOfBirth;
    private String address;
    private String gender;

    @NotNull
    private Long departmentId;

    @NotNull
    private Long positionId;

    @NotNull
    private LocalDate hireDate;

    @NotNull
    private BigDecimal baseSalary;
}
