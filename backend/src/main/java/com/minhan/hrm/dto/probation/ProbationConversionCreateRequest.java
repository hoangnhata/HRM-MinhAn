package com.minhan.hrm.dto.probation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDate;

@Data
public class ProbationConversionCreateRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private LocalDate officialDate;

    @NotBlank
    @Size(max = 1000)
    private String reason;
}
