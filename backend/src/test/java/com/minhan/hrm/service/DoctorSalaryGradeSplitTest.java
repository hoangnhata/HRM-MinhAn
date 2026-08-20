package com.minhan.hrm.service;

import com.minhan.hrm.dto.salary.ComputedSalaryGradeDto;
import com.minhan.hrm.entity.EmployeeSalaryProfile;
import com.minhan.hrm.entity.SalaryCategory;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.minhan.hrm.exception.ApiException;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DoctorSalaryGradeSplitTest {

    @Test
    void doctorKeepsImportedBaseAndReceivesScaleRemainderAsProductSalary() {
        EmployeeSalaryProfileService service = new EmployeeSalaryProfileService(
                null, null, null, null, null, null);
        EmployeeSalaryProfile profile = EmployeeSalaryProfile.builder()
                .salaryCategory(SalaryCategory.DOCTOR)
                .importedInsuranceSalary(new BigDecimal("6000000"))
                .importedProductSalary(new BigDecimal("8000000"))
                .build();
        ComputedSalaryGradeDto scaleGrade = ComputedSalaryGradeDto.builder()
                .gradeLevel(3)
                .gradeLabel("4-6 năm")
                .yearsRange("4-6 năm")
                .coefficient(BigDecimal.ZERO)
                .insuranceSalary(BigDecimal.ZERO)
                .productSalary(BigDecimal.ZERO)
                .scaleSalary(new BigDecimal("20000000"))
                .build();

        ComputedSalaryGradeDto result = ReflectionTestUtils.invokeMethod(
                service, "applyImportedSalaries", scaleGrade, profile);

        assertThat(result).isNotNull();
        assertThat(result.getInsuranceSalary()).isEqualByComparingTo("6000000");
        assertThat(result.getProductSalary()).isEqualByComparingTo("14000000");
        assertThat(result.getInsuranceSalary().add(result.getProductSalary()))
                .isEqualByComparingTo("20000000");
    }

    @Test
    void doctorDoesNotFallBackToImportedProductWhenScaleIsMissing() {
        EmployeeSalaryProfileService service = new EmployeeSalaryProfileService(
                null, null, null, null, null, null);
        EmployeeSalaryProfile profile = EmployeeSalaryProfile.builder()
                .salaryCategory(SalaryCategory.DOCTOR)
                .importedInsuranceSalary(new BigDecimal("6000000"))
                .importedProductSalary(new BigDecimal("8000000"))
                .build();
        ComputedSalaryGradeDto missingScale = ComputedSalaryGradeDto.builder()
                .gradeLevel(0)
                .gradeLabel("—")
                .yearsRange("—")
                .coefficient(BigDecimal.ZERO)
                .insuranceSalary(BigDecimal.ZERO)
                .productSalary(BigDecimal.ZERO)
                .scaleSalary(BigDecimal.ZERO)
                .build();

        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                service, "applyImportedSalaries", missingScale, profile))
                .isInstanceOf(ApiException.class);
    }
}
