package com.minhan.hrm.dto.shiftconfig;

import com.minhan.hrm.entity.ShiftConfigChangeSeason;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalTime;

@Data
public class ShiftConfigChangeCreateDto {

    @NotNull
    private Long employeeId;

    /** SUMMER | WINTER | BOTH */
    @NotNull
    private ShiftConfigChangeSeason season;

    /** Giờ mùa hè, hoặc giờ mùa duy nhất khi chọn một mùa. */
    @NotNull
    private LocalTime morningStart;

    @NotNull
    private LocalTime morningEnd;

    @NotNull
    private LocalTime afternoonStart;

    @NotNull
    private LocalTime afternoonEnd;

    /** Bắt buộc khi season = BOTH. */
    private LocalTime winterMorningStart;
    private LocalTime winterMorningEnd;
    private LocalTime winterAfternoonStart;
    private LocalTime winterAfternoonEnd;

    /** Mặc định ~2/3 công nếu bỏ trống. */
    private BigDecimal morningUnits;

    /** Mặc định ~1/3 công nếu bỏ trống. */
    private BigDecimal afternoonUnits;

    @Size(max = 1000)
    private String reason;
}
