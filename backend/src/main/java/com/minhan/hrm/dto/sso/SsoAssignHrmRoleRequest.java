package com.minhan.hrm.dto.sso;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class SsoAssignHrmRoleRequest {

    @NotBlank
    private String roleCode;
}
