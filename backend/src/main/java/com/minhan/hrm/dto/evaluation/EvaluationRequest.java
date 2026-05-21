package com.minhan.hrm.dto.evaluation;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class EvaluationRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private Integer periodYear;

    private Integer periodMonth;

    /** 1–4 nếu đánh giá theo quý */
    private Integer quarter;

    @NotNull
    @DecimalMin("0")
    @DecimalMax("100")
    private BigDecimal score;

    @NotBlank
    private String grade;

    private String comments;
}
