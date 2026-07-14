package com.minhan.hrm.dto.salary;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;

@Value
@Builder
public class DoctorScaleEntryDto {
    Long id;
    String qualificationCode;
    String qualificationName;
    String timeLabel;
    BigDecimal yearsMin;
    BigDecimal yearsMax;
    BigDecimal totalSalary;
}
