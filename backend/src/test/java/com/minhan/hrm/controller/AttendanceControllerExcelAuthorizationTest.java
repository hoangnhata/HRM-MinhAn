package com.minhan.hrm.controller;

import org.junit.jupiter.api.Test;
import org.springframework.security.access.prepost.PreAuthorize;

import java.lang.reflect.Method;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AttendanceControllerExcelAuthorizationTest {

    @Test
    void excelExportAllowsUnifiedHeadDepartmentRole() throws Exception {
        Method method = AttendanceController.class.getMethod(
                "exportMonthlyReport", int.class, int.class, Long.class);
        PreAuthorize authorization = method.getAnnotation(PreAuthorize.class);

        assertNotNull(authorization);
        assertTrue(authorization.value().contains("HEAD_DEPARTMENT"));
    }
}
