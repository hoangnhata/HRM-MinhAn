package com.minhan.hrm.dto.evaluation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.Map;

@Data
public class NursingEvaluationChannelSubmitRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private Integer periodYear;

    @NotNull
    private Integer periodMonth;

    @NotBlank
    private String templateCode;

    /**
     * Một trong: truongKhoa (khoa phòng) | ddt (điều dưỡng trưởng)
     */
    @NotBlank
    private String channel;

    /**
     * Theo từng tiêu chí (id trong template): chỉ điểm của kênh trên.
     */
    @NotNull
    private Map<String, BigDecimal> scores;

    /**
     * Ghi chú theo từng tiêu chí (cùng kênh đang lưu), tùy chọn.
     */
    private Map<String, String> notes;

    private String comments;
}
