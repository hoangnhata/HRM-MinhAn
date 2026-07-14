package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class ChamcongSyncScheduleUpdateRequest {

    @NotNull
    private Boolean autoSyncEnabled;

    /** Giờ đồng bộ hàng ngày — HH:mm (24h) */
    @NotNull
    @Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$", message = "syncTime phải dạng HH:mm (00:00–23:59)")
    private String syncTime;
}
