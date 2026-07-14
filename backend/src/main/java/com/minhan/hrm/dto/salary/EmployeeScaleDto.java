package com.minhan.hrm.dto.salary;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;
import java.util.List;

@Value
@Builder
public class EmployeeScaleDto {
    String scaleType;
    String title;
    BigDecimal baseTotalAtCoef1;
    BigDecimal baseInsuranceAtCoef1;
    BigDecimal baseProductAtCoef1;
    List<EmployeeScaleTierDto> tiers;
}
