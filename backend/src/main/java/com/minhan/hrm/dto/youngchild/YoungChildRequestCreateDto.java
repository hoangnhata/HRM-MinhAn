package com.minhan.hrm.dto.youngchild;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDate;

@Data
public class YoungChildRequestCreateDto {

    @NotNull
    private Long employeeId;

    @NotNull
    private LocalDate startDate;

    @NotNull
    private LocalDate endDate;

    /** true = đề xuất bật chế độ */
    @NotNull
    private Boolean enabled;

    @Size(max = 1000)
    private String reason;
}
