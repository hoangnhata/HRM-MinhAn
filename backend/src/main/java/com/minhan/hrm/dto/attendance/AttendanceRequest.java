package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalTime;

@Data
public class AttendanceRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private LocalDate workDate;

    private LocalTime checkIn;
    private LocalTime checkOut;

    @NotNull
    private String status;

    private String note;
}
