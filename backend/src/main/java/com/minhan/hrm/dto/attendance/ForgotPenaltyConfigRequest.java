package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class ForgotPenaltyConfigRequest {

    @NotNull
    @DecimalMin("0")
    private BigDecimal tier1Amount;

    @Min(2)
    @Max(31)
    private int tier2Min;

    @Min(2)
    @Max(31)
    private int tier2Max;

    @NotNull
    @DecimalMin("0")
    private BigDecimal tier2Amount;

    @NotNull
    @DecimalMin("0")
    private BigDecimal tier3Amount;
}
