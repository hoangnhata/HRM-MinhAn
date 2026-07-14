package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class EmployeeContinuousShiftRequest {

    @NotNull
    private Boolean continuousShift;

    @NotNull
    private Integer year;

    @NotNull
    private Integer month;
}
