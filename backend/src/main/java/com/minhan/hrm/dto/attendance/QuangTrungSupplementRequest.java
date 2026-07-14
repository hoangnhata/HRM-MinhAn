package com.minhan.hrm.dto.attendance;

import com.minhan.hrm.entity.AttendanceUpdateKind;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalTime;

@Data
public class QuangTrungSupplementRequest {

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
