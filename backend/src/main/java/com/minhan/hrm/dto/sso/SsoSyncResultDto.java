package com.minhan.hrm.dto.sso;

import com.minhan.hrm.entity.UserRole;
import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class SsoSyncResultDto {
    String loginPhone;
    String ssoRoleCode;
    UserRole hrmRole;
    Long hrmUserId;
    String hrmUsername;
    boolean updated;
}
