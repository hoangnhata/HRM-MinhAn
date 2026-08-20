package com.minhan.hrm.dto.attendance;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.util.List;

@Data
public class EmployeeContinuousShiftRequest {

    @NotNull
    private Integer year;

    @NotNull
    private Integer month;

    /**
     * Ngày + ca/khung giờ tương ứng (ưu tiên hơn {@link #dates}).
     * Thay thế toàn bộ tháng.
     */
    @Valid
    private List<ContinuousShiftDayAssignment> days;

    /**
     * Danh sách ngày ca thông tầm trong tháng (thay thế toàn bộ tháng).
     * Giờ dùng cấu hình mùa/NV nếu không gửi {@link #days}.
     * Nếu null và {@link #continuousShift} khác null → bật cả tháng / tắt hết (tương thích cũ).
     */
    private List<LocalDate> dates;

    /** Tương thích: true = mọi ngày trong tháng, false = không ngày nào. */
    private Boolean continuousShift;
}
