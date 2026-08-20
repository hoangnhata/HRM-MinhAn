package com.minhan.hrm.dto.shiftconfig;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ShiftConfigChangeReviewDto {

    @NotNull
    private Boolean approved;

    @Size(max = 1000)
    private String comment;
}
