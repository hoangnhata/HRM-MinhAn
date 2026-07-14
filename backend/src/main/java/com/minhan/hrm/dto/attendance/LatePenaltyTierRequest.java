package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class LatePenaltyTierRequest {

    @Min(1)
    private int sortOrder;

    @Min(0)
    private int minMinutes;

    private Integer maxMinutes;

    @NotNull
    @DecimalMin("0")
    private BigDecimal amount;

    private boolean requiresDiscipline;

    private String note;
}
