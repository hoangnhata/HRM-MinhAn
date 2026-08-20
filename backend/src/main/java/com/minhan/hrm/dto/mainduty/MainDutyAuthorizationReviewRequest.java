package com.minhan.hrm.dto.mainduty;

import lombok.Data;

@Data
public class MainDutyAuthorizationReviewRequest {
    private Boolean approved;
    private String comment;
}
