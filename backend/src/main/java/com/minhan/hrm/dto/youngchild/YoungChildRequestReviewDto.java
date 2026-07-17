package com.minhan.hrm.dto.youngchild;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class YoungChildRequestReviewDto {

    @NotNull
    private Boolean approved;

    @Size(max = 1000)
    private String comment;
}
