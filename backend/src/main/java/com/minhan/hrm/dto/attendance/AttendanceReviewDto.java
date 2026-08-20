package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalTime;

@Data
public class AttendanceReviewDto {

    @NotNull
    private Boolean approved;

    private String comment;

    /** HR / Giám đốc: true = không trừ tiền (quên chấm hoặc phạt muộn/sớm) */
    private Boolean waiveForgotFine;

    /** Trưởng phòng ĐD / HCNS được hiệu chỉnh khung giờ trước khi duyệt đơn điều động. */
    private LocalTime requestedStart;
    private LocalTime requestedEnd;
    private LocalTime requestedAfternoonStart;
    private LocalTime requestedAfternoonEnd;
}
