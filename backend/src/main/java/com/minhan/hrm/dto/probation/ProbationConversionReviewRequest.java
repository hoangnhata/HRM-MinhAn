package com.minhan.hrm.dto.probation;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ProbationConversionReviewRequest {

    @NotNull
    private Boolean approved;

    @Size(max = 1000)
    private String comment;
}
