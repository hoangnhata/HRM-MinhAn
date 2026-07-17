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
}
