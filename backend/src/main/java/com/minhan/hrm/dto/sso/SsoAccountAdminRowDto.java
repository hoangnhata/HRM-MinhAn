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
    /** Vai trò ERP — UserAccounts.RoleId */
    Integer roleId;
    /** Vai trò Tài sản — UserAccounts.roleId_ts */
    Integer roleIdTs;
    String fullName;
    String departmentName;
    /** Bộ phận (workUnitDetail) từ hồ sơ HRM */
    String workUnitDetail;
    Long hrmEmployeeId;
}
