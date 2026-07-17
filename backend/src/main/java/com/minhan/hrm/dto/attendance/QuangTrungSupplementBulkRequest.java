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

    @NotNull
    private LocalTime requestedStart;

    @NotNull
    private LocalTime requestedEnd;

    private LocalTime requestedAfternoonStart;
    private LocalTime requestedAfternoonEnd;
}
