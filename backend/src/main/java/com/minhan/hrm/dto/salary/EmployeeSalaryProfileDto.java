package com.minhan.hrm.dto.salary;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;

@Value
@Builder
public class EmployeeSalaryProfileDto {
    Long employeeId;
    String salaryCategory;
    String employeeBlock;
    String qualification;
    int tierGroup;
    String doctorQualificationCode;
    String qualificationNote;
    BigDecimal yearsOfService;
    BigDecimal seniorityYears;
    BigDecimal degreeConversionYears;
    /** Tổng quy đổi nâng lương sớm (năm) */
    BigDecimal priorRaiseYears;
    /** Chi tiết từng lần nâng lương sớm */
    java.util.List<EarlyRaiseConversionDto> earlyRaiseConversions;
    BigDecimal professionalAttractionSalary;
    /** Thời gian bắt đầu tính thang bảng lương */
    java.time.LocalDate salaryScaleStartDate;
    /** Ngày chốt thâm niên gốc (vd. 30/06/2026) */
    java.time.LocalDate seniorityAsOfDate;
    /** Thâm niên gốc tại ngày chốt */
    BigDecimal baseSeniorityYears;
    boolean ldg;
    BigDecimal importedInsuranceSalary;
    BigDecimal importedProductSalary;
    ComputedSalaryGradeDto computedGrade;
    BigDecimal totalSalary;
    boolean canViewSensitive;
    boolean canEdit;
}
