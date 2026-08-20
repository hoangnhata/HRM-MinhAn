package com.minhan.hrm.dto.account;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AvatarSaveRequest {
    /** data:image/png;base64,... hoặc raw base64 */
    @NotBlank
    private String imageBase64;
}
