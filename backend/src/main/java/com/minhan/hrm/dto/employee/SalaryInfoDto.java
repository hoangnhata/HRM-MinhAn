package com.minhan.hrm.dto.employee;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;
import java.time.LocalDate;

@Value
@Builder
public class SalaryInfoDto {
    Long id;
    BigDecimal baseSalary;
    BigDecimal allowance;
    LocalDate lastRaiseDate;
    LocalDate nextReviewDate;
}
