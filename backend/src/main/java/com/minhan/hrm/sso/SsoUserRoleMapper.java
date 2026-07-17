package com.minhan.hrm.sso;

import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import org.springframework.http.HttpStatus;

import java.util.Locale;
import java.util.Set;

/** Map RoleCode SSO (AppCode=HRM) ↔ enum UserRole HRM. */
public final class SsoUserRoleMapper {

    public static final String APP_CODE_HRM = "HRM";

    public static final Set<String> HRM_ROLE_CODES = Set.of(
            "ADMIN", "EMPLOYEE", "HR", "HEAD_DEPARTMENT", "HEAD_NURSING", "DIRECTOR");

    private SsoUserRoleMapper() {}

    public static UserRole toUserRole(String roleCode) {
        if (roleCode == null || roleCode.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu RoleCode SSO");
        }
        String code = roleCode.trim().toUpperCase(Locale.ROOT);
        try {
            UserRole role = UserRole.valueOf(code);
            if (!HRM_ROLE_CODES.contains(role.name())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "RoleCode không thuộc HRM: " + code);
            }
            return role;
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "RoleCode SSO không hợp lệ: " + code);
        }
    }

    public static String toRoleCode(UserRole role) {
        if (role == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu UserRole");
        }
        return role.name();
    }
}
