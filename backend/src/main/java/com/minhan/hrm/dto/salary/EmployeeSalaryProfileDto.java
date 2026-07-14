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
    BigDecimal priorRaiseYears;
    BigDecimal professionalAttractionSalary;
    ComputedSalaryGradeDto computedGrade;
    BigDecimal totalSalary;
    boolean canViewSensitive;
    boolean canEdit;
}
