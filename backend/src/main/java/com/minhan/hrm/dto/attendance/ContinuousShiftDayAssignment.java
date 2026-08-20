package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalTime;

@Data
public class ContinuousShiftDayAssignment {

    @NotNull
    private LocalDate date;

    /** Chọn theo danh mục ca; nếu có thì giờ lấy từ ca (có thể ghi đè bằng start/end). */
    private Long shiftTypeId;

    private LocalTime continuousStart;

    private LocalTime continuousEnd;
}
