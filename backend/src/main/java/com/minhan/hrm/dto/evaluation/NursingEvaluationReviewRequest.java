package com.minhan.hrm.dto.evaluation;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class NursingEvaluationReviewRequest {

    @NotNull
    private Boolean approved;

    private String comment;
}
