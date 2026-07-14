package com.minhan.hrm.dto.salary;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;

@Value
@Builder
public class EmployeeScaleGradeDto {
    int gradeLevel;
    String gradeLabel;
    String yearsRange;
    BigDecimal coefficient;
    BigDecimal insuranceSalary;
    BigDecimal productSalary;
    BigDecimal totalIncome;
}
