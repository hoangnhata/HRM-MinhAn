package com.minhan.hrm.dto.employee;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;
import java.time.LocalDate;

@Value
@Builder
public class ContractDto {
    Long id;
    String contractType;
    LocalDate startDate;
    LocalDate endDate;
    BigDecimal salaryBase;
    String documentPath;
    String note;
}
