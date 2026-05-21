package com.minhan.hrm.dto.employee;

import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.UserRole;
import lombok.Builder;
import lombok.Value;

import java.time.LocalDate;

@Value
@Builder
public class EmployeeSummaryDto {
    Long id;
    String employeeCode;
    Long userId;
    String username;
    String fullName;
    String departmentName;
    String positionTitle;
    UserRole role;
    EmployeeStatus status;
    LocalDate hireDate;
}
