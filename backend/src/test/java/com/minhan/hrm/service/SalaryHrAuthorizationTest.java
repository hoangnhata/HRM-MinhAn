package com.minhan.hrm.service;

import com.minhan.hrm.controller.PayrollController;
import com.minhan.hrm.controller.WorkforceImportController;
import com.minhan.hrm.dto.payroll.PayrollRequest;
import com.minhan.hrm.dto.salary.EmployeeSalaryProfileRequest;
import com.minhan.hrm.dto.salary.SalaryScaleEntryDto;
import com.minhan.hrm.entity.DutyRoleTier;
import com.minhan.hrm.entity.SalaryScaleType;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.multipart.MultipartFile;

import java.lang.reflect.Method;
import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SalaryHrAuthorizationTest {

    @Test
    void hrCanManageSalaryProfilesAndSalaryScales() throws Exception {
        assertAllowsHr(EmployeeSalaryProfileService.class, "upsertProfile",
                Long.class, EmployeeSalaryProfileRequest.class, String.class);
        assertAllowsHr(EmployeeSalaryProfileService.class, "recalculateAll", String.class);
        assertAllowsHr(EmployeeSalaryProfileService.class, "exportAllProfiles", String.class);

        assertAllowsHr(SalaryScaleService.class, "updateEmployeeScaleBase",
                SalaryScaleType.class, BigDecimal.class, String.class, String.class);
        assertAllowsHr(SalaryScaleService.class, "saveEntry",
                SalaryScaleEntryDto.class, String.class);
        assertAllowsHr(SalaryScaleService.class, "deleteEntry", Long.class, String.class);
    }

    @Test
    void hrCanImportSalaryScaleAndManagePayroll() throws Exception {
        assertAllowsHr(WorkforceImportController.class, "importSalaryScale", MultipartFile.class);

        assertAllowsHr(PayrollController.class, "all");
        assertAllowsHr(PayrollController.class, "upsert", PayrollRequest.class);
        assertAllowsHr(PayrollController.class, "delete", Long.class);
        assertAllowsHr(PayrollService.class, "listAll");
        assertAllowsHr(PayrollService.class, "upsert", PayrollRequest.class);
        assertAllowsHr(PayrollService.class, "delete", Long.class);
    }

    @Test
    void specialistDoctorTierUsesRequestedLabel() {
        assertEquals("Bác sĩ chuyên khoa", DutyRoleTier.BS_NSN_XQ_SA.getLabel());
    }

    private static void assertAllowsHr(
            Class<?> targetClass, String methodName, Class<?>... parameterTypes) throws Exception {
        Method method = targetClass.getMethod(methodName, parameterTypes);
        PreAuthorize authorization = method.getAnnotation(PreAuthorize.class);

        assertNotNull(authorization,
                () -> targetClass.getSimpleName() + "." + methodName + " phải khai báo phân quyền");
        assertTrue(authorization.value().contains("HR"),
                () -> targetClass.getSimpleName() + "." + methodName + " phải cho phép vai trò HR");
    }
}
