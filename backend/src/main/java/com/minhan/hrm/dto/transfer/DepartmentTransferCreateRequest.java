package com.minhan.hrm.dto.transfer;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDate;

@Data
public class DepartmentTransferCreateRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private Long toDepartmentId;

    private Long toPositionId;

    @NotNull
    private LocalDate effectiveDate;

    @NotBlank
    @Size(max = 1000)
    private String reason;
}
