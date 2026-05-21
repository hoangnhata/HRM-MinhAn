package com.minhan.hrm.dto.payroll;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class PayrollRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private Integer periodYear;

    @NotNull
    private Integer periodMonth;

    private Integer workingDays;

    @NotNull
    private BigDecimal grossAmount;

    private BigDecimal deductionAmount;

    @NotNull
    private BigDecimal netAmount;

    private String note;

    private boolean finalized;
}
