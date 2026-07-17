package com.minhan.hrm.dto.youngchild;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class YoungChildRequestCreateDto {

    @NotNull
    private Long employeeId;

    @NotNull
    @Min(2000)
    @Max(2100)
    private Integer year;

    @NotNull
    @Min(1)
    @Max(12)
    private Integer month;

    /** true = đề xuất bật chế độ */
    @NotNull
    private Boolean enabled;

    @Size(max = 1000)
    private String reason;
}
