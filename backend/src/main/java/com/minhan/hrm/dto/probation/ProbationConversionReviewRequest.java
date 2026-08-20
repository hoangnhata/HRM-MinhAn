package com.minhan.hrm.dto.probation;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ProbationConversionReviewRequest {

    /** HCNS / Giám đốc chỉ duyệt hoặc từ chối. */
    private Boolean approved;

    @Size(max = 1000)
    private String comment;
}
