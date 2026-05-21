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

    @NotBlank
    private String username;

    @NotBlank
    private String password;

    @Email
    @NotBlank
    private String email;

    @NotNull
    private UserRole role;

    @NotBlank
    private String fullName;

    private String phone;
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
