package com.minhan.hrm.dto.salary;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;
import java.util.List;

@Value
@Builder
public class EmployeeScaleTierDto {
    int tierGroup;
    String tierLabel;
    List<EmployeeScaleGradeDto> grades;
}
