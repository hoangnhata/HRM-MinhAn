package com.minhan.hrm.dto.sso;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class SsoHrmRoleDto {
    Long accountId;
    String loginPhone;
    Integer userEnrollNumber;
    String roleCode;
    String roleName;
    String appCode;
    /** Vai trò ERP — UserAccounts.RoleId */
    Integer roleId;
    /** Vai trò Tài sản — UserAccounts.roleId_ts */
    Integer roleIdTs;
}
