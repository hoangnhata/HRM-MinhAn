package com.minhan.hrm.dto.salary;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;

@Value
@Builder
public class SalaryScaleEntryDto {
    Long id;
    String scaleType;
    String qualification;
    int gradeLevel;
    String yearsRange;
    BigDecimal coefficient;
    BigDecimal baseInsuranceSalary;
    BigDecimal productSalary;
    BigDecimal totalIncome;
}
