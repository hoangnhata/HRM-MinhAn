package com.minhan.hrm.dto.attendance;

import com.minhan.hrm.entity.AttendanceUpdateKind;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

@Data
public class QuangTrungSupplementBulkRequest {

    @NotEmpty
    private List<Long> employeeIds;

    @NotNull
    private LocalDate workDate;

    @NotNull
    private AttendanceUpdateKind updateKind;

    private String reason;

    /**
     * Tuỳ chọn — nếu null, từng NV dùng khung giờ ca của mình.
     * Nếu có đủ giờ, dùng chung (override) cho mọi NV.
     */
    private LocalTime requestedStart;
    private LocalTime requestedEnd;
    private LocalTime requestedAfternoonStart;
    private LocalTime requestedAfternoonEnd;
}
