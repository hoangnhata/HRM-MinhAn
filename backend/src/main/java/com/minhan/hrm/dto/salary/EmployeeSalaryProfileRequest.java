package com.minhan.hrm.dto.salary;

import com.minhan.hrm.entity.EmployeeSalaryBlock;
import com.minhan.hrm.entity.SalaryCategory;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class EmployeeSalaryProfileRequest {

    @NotNull
    private SalaryCategory salaryCategory;

    private EmployeeSalaryBlock employeeBlock;

    private String qualification;

    @Min(1)
    @Max(3)
    private int tierGroup = 3;

    private String doctorQualificationCode;

    private String qualificationNote;

    @DecimalMin("0")
    private BigDecimal degreeConversionYears;

    @DecimalMin("0")
    private BigDecimal priorRaiseYears;

    @DecimalMin("0")
    private BigDecimal professionalAttractionSalary;
}
