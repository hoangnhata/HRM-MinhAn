package com.minhan.hrm.sso;

import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SsoUserRoleMapperTest {

    @Test
    void mapsUnifiedHeadRoleAndLegacyNursingRole() {
        assertEquals(UserRole.ADMIN, SsoUserRoleMapper.toUserRole("ADMIN"));
        assertEquals(UserRole.EMPLOYEE, SsoUserRoleMapper.toUserRole("employee"));
        assertEquals(UserRole.HR, SsoUserRoleMapper.toUserRole("HR"));
        assertEquals(UserRole.HEAD_DEPARTMENT, SsoUserRoleMapper.toUserRole("HEAD_NURSING"));
        assertEquals(UserRole.HEAD_DEPARTMENT, SsoUserRoleMapper.toUserRole("HEAD_DEPARTMENT"));
        assertEquals(UserRole.HEAD_HR, SsoUserRoleMapper.toUserRole("HEAD_HR"));
        assertEquals(UserRole.DIRECTOR, SsoUserRoleMapper.toUserRole("DIRECTOR"));
    }

    @Test
    void rejectsUnknownCode() {
        assertThrows(ApiException.class, () -> SsoUserRoleMapper.toUserRole("guest"));
        assertThrows(ApiException.class, () -> SsoUserRoleMapper.toUserRole(""));
    }

    @Test
    void toRoleCodeRoundTrip() {
        assertEquals("HEAD_DEPARTMENT", SsoUserRoleMapper.toRoleCode(UserRole.HEAD_DEPARTMENT));
        assertEquals("HEAD_HR", SsoUserRoleMapper.toRoleCode(UserRole.HEAD_HR));
    }
}
