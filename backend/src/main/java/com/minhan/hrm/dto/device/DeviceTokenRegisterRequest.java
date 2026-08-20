package com.minhan.hrm.dto.device;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class DeviceTokenRegisterRequest {
    @NotBlank
    @Size(max = 512)
    private String token;

    /** ANDROID | IOS | WEB */
    @Size(max = 32)
    private String platform = "ANDROID";
}
