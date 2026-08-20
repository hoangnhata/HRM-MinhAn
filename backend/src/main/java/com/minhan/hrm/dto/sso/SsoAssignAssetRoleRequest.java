package com.minhan.hrm.dto.sso;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class SsoAssignAssetRoleRequest {

    /** Vai trò Tài sản: 1=Quản lý, 2=Duyệt, 3=Nhân viên, 4=BP Mua sắm */
    @NotNull
    private Integer roleIdTs;
}
