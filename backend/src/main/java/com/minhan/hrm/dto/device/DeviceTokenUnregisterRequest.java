package com.minhan.hrm.dto.device;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class DeviceTokenUnregisterRequest {
    @NotBlank
    @Size(max = 512)
    private String token;
}
