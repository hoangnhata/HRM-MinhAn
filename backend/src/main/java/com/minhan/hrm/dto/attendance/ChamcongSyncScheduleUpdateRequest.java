package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class ChamcongSyncScheduleUpdateRequest {

    @NotNull
    private Boolean autoSyncEnabled;

    /**
     * Chu kỳ tự đồng bộ (phút). Mặc định 1 = gần real-time.
     * Cho phép 1–60.
     */
    @NotNull
    @Min(1)
    @Max(60)
    private Integer intervalMinutes;

    /**
     * Giữ tương thích UI cũ (HH:mm) — không còn dùng để hẹn lịch ngày.
     * Có thể bỏ trống.
     */
    @Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$", message = "syncTime phải dạng HH:mm (00:00–23:59)")
    private String syncTime;
}
