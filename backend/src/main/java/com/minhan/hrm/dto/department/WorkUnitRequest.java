package com.minhan.hrm.dto.department;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class WorkUnitRequest {

    @NotBlank
    @Size(max = 255)
    private String name;

    @Size(max = 500)
    private String description;
}
