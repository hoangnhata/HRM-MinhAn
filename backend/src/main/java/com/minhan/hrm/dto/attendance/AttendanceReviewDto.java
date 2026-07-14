package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class AttendanceReviewDto {

    @NotNull
    private Boolean approved;

    private String comment;

    /** HR duyệt đơn cập nhật: true = không trừ tiền quên chấm */
    private Boolean waiveForgotFine;
}
