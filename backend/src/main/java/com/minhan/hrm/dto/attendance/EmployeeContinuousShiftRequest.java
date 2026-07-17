package com.minhan.hrm.dto.attendance;

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
     * Danh sách ngày ca thông tầm trong tháng (thay thế toàn bộ tháng).
     * Nếu null và {@link #continuousShift} khác null → bật cả tháng / tắt hết (tương thích cũ).
     */
    private List<LocalDate> dates;

    /** Tương thích: true = mọi ngày trong tháng, false = không ngày nào. */
    private Boolean continuousShift;
}
