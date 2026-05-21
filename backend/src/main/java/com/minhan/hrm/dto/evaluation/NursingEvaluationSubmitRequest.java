package com.minhan.hrm.dto.evaluation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

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
     * Theo từng tiêu chí: truongKhoa, ddt (điểm); truongKhoaNote, ddtNote (ghi chú từng dòng, tùy chọn).
     */
    @NotNull
    private Map<String, Map<String, Object>> scores;

    private String comments;
}
