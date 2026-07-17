package com.minhan.hrm.dto.sso;

import lombok.Getter;
import lombok.Setter;

/**
 * Payload cấp tài khoản đăng nhập HRM. Mọi trường đều tùy chọn:
 * password mặc định "123", roleId (Vai trò ERP) mặc định 1, roleIdTs mặc định 3,
 * hrmRoleCode (Chức danh HRM — 6 role phần mềm) mặc định EMPLOYEE.
 */
@Getter
@Setter
public class AccountGrantRequest {
    private String password;
    /** Vai trò ERP (cột legacy UserAccounts.RoleId): 1 Nhân viên, 2 Tổ trưởng, 3 Quản lý */
    private Integer roleId;
    /** Vai trò module Tài sản (UserAccounts.roleId_ts) */
    private Integer roleIdTs;
    /** Chức danh HRM — RoleCode trên SSO UserAppRoles (ADMIN, EMPLOYEE, HR, …) */
    private String hrmRoleCode;
}
