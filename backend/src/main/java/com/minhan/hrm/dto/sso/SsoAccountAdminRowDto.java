package com.minhan.hrm.dto.sso;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class SsoAccountAdminRowDto {
    Long accountId;
    String loginPhone;
    Integer userEnrollNumber;
    String roleCode;
    /** Tên role tiếng Việt từ SSO Roles.RoleName */
    String roleName;
    String fullName;
    String departmentName;
    Long hrmEmployeeId;
}
