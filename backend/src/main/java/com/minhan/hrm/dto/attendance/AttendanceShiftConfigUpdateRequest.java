package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalTime;

@Data
public class AttendanceShiftConfigUpdateRequest {

    @NotNull
    private LocalTime morningStart;
    @NotNull
    private LocalTime morningEnd;
    @NotNull
    private LocalTime afternoonStart;
    @NotNull
    private LocalTime afternoonEnd;
    @NotNull
    private BigDecimal morningUnits;
    @NotNull
    private BigDecimal afternoonUnits;

    @NotNull
    private Integer morningInBeforeMin;
    @NotNull
    private Integer morningInAfterMin;
    @NotNull
    private Integer morningOutBeforeMin;
    @NotNull
    private Integer morningOutAfterMin;
    @NotNull
    private Integer afternoonInBeforeMin;
    @NotNull
    private Integer afternoonInAfterMin;
    @NotNull
    private Integer afternoonOutBeforeMin;
    @NotNull
    private Integer afternoonOutAfterMin;
}
