package com.minhan.hrm.dto.employee;

import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.UserRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class EmployeeUpdateRequest {

    @Email(message = "Email không hợp lệ")
    private String email;

    private UserRole role;

    private String fullName;
    private String phone;
    private String idCardNumber;
    private LocalDate dateOfBirth;
    private String address;
    private String gender;

    private Long departmentId;
    private Long positionId;

    private LocalDate hireDate;

    private BigDecimal baseSalary;
    private BigDecimal allowance;
    private LocalDate lastRaiseDate;
    private LocalDate nextReviewDate;

    @NotNull
    private EmployeeStatus status;
}
