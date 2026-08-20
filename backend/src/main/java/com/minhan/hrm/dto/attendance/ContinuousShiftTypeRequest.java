package com.minhan.hrm.dto.attendance;

import com.minhan.hrm.entity.ContinuousShiftKind;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalTime;

@Data
public class ContinuousShiftTypeRequest {

    @NotBlank
    @Size(max = 100)
    private String name;

    /** CONTINUOUS (thông tầm) hoặc SPLIT (sáng–chiều). Mặc định CONTINUOUS. */
    private ContinuousShiftKind kind;

    /** Bắt buộc với CONTINUOUS; với SPLIT có thể bỏ trống (lấy từ morningStart / afternoonEnd). */
    private LocalTime startTime;
    private LocalTime endTime;

    private LocalTime morningStart;
    private LocalTime morningEnd;
    private LocalTime afternoonStart;
    private LocalTime afternoonEnd;

    @NotNull
    private Integer checkInBeforeMin;
    @NotNull
    private Integer checkInAfterMin;
    @NotNull
    private Integer checkOutBeforeMin;
    @NotNull
    private Integer checkOutAfterMin;

    private Integer morningOutBeforeMin;
    private Integer morningOutAfterMin;
    private Integer afternoonInBeforeMin;
    private Integer afternoonInAfterMin;

    private Boolean active;
}
