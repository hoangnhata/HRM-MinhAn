package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

@Data
public class EmployeeYoungChildRequest {

    @NotNull
    private Boolean youngChild;

    /** Ngày bắt đầu bật hoặc ngày bắt đầu tắt; mặc định hôm nay. */
    private LocalDate effectiveDate;
}
