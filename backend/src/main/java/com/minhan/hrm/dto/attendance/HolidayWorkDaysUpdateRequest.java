package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Data
public class HolidayWorkDaysUpdateRequest {

    @NotNull
    @Min(2000)
    @Max(2100)
    private Integer year;

    @NotNull
    @Min(1)
    @Max(12)
    private Integer month;

    /** Các ngày lễ trong tháng (chỉ lấy ngày thuộc year/month). */
    @NotNull
    private List<LocalDate> dates = new ArrayList<>();
}
