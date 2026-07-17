package com.minhan.hrm.sso;

import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SsoUserRoleMapperTest {

    @Test
    void mapsAllSixHrmRoles() {
        assertEquals(UserRole.ADMIN, SsoUserRoleMapper.toUserRole("ADMIN"));
        assertEquals(UserRole.EMPLOYEE, SsoUserRoleMapper.toUserRole("employee"));
        assertEquals(UserRole.HR, SsoUserRoleMapper.toUserRole("HR"));
        assertEquals(UserRole.HEAD_DEPARTMENT, SsoUserRoleMapper.toUserRole("HEAD_DEPARTMENT"));
        assertEquals(UserRole.HEAD_NURSING, SsoUserRoleMapper.toUserRole("HEAD_NURSING"));
        assertEquals(UserRole.DIRECTOR, SsoUserRoleMapper.toUserRole("DIRECTOR"));
    }

    @Test
    void rejectsUnknownCode() {
        assertThrows(ApiException.class, () -> SsoUserRoleMapper.toUserRole("guest"));
        assertThrows(ApiException.class, () -> SsoUserRoleMapper.toUserRole(""));
    }

    @Test
    void toRoleCodeRoundTrip() {
        assertEquals("HEAD_NURSING", SsoUserRoleMapper.toRoleCode(UserRole.HEAD_NURSING));
    }
}
