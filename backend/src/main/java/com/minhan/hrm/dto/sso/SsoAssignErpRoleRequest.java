package com.minhan.hrm.dto.sso;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class SsoAssignErpRoleRequest {

    /** Vai trò ERP: 1=Nhân viên, 2=Tổ trưởng, 3=Quản lý */
    @NotNull
    private Integer roleId;
}
