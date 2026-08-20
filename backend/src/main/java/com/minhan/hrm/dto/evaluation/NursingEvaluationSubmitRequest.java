package com.minhan.hrm.dto.evaluation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.Map;

@Data
public class NursingEvaluationSubmitRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private Integer periodYear;

    @NotNull
    private Integer periodMonth;

    @NotBlank
    private String templateCode;

    /**
     * Điểm theo id tiêu chí trong template (một cột «Điểm đạt»).
     */
    @NotNull
    private Map<String, BigDecimal> scores;

    /** Ghi chú theo tiêu chí (tùy chọn). */
    private Map<String, String> notes;

    private String comments;

    /**
     * true = gửi HCNS duyệt (ký trưởng khoa); false = lưu nháp.
     */
    @NotNull
    private Boolean submitForReview;
}
