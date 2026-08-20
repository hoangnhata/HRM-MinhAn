package com.minhan.hrm.dto.account;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class SignatureSaveRequest {
    /** data:image/png;base64,... hoặc chuỗi base64 thuần */
    @NotBlank
    private String imageBase64;
}
