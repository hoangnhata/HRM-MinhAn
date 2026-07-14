package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class EmployeeYoungChildRequest {

    @NotNull
    private Boolean youngChild;

    @NotNull
    private Integer year;

    @NotNull
    private Integer month;
}
