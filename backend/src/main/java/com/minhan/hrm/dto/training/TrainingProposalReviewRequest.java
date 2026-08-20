package com.minhan.hrm.dto.training;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class TrainingProposalReviewRequest {

    private Boolean approved;

    @Size(max = 1000)
    private String comment;

    /** Bắt buộc khi HCNS duyệt chuyển Giám đốc. */
    @Size(max = 255)
    private String monthlySupport;

    /** Bắt buộc khi HCNS duyệt chuyển Giám đốc. */
    @Size(max = 255)
    private String postCourseCommitment;
}
