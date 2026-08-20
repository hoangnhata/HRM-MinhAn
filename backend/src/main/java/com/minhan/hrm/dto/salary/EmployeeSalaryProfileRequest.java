package com.minhan.hrm.dto.salary;

import com.minhan.hrm.entity.EmployeeSalaryBlock;
import com.minhan.hrm.entity.SalaryCategory;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

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

    /** Chi tiết quy đổi nâng lương sớm (ngày + hệ số năm). Tổng → priorRaiseYears. */
    private java.util.List<EarlyRaiseConversionDto> earlyRaiseConversions;

    @DecimalMin("0")
    private BigDecimal professionalAttractionSalary;

    /** Thời gian bắt đầu tính thang bảng lương (Excel). */
    private LocalDate salaryScaleStartDate;

    /** Ngày chốt thâm niên (vd. 30/06/2026). */
    private LocalDate seniorityAsOfDate;

    /** Thâm niên (năm) tại ngày chốt. */
    @DecimalMin("0")
    private BigDecimal baseSeniorityYears;

    /** LĐG — bậc cố định, không nhảy theo thang. */
    private Boolean ldg;

    private String fixedGradeLabel;

    /** Lương đóng BH / cơ bản (import hoặc nhập tay). */
    @DecimalMin("0")
    private BigDecimal importedInsuranceSalary;

    /** Lương đảm bảo sản phẩm. */
    @DecimalMin("0")
    private BigDecimal importedProductSalary;
}
