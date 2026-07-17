package com.minhan.hrm.dto.sso;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class SsoRoleCatalogDto {
    Integer roleId;
    String appCode;
    String roleCode;
    String roleName;
    boolean active;
}
