package com.minhan.hrm.entity;

import com.minhan.hrm.dto.salary.EarlyRaiseConversionDto;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "employee_salary_profile")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmployeeSalaryProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false, unique = true)
    private Employee employee;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "salary_category", nullable = false, length = 16)
    private SalaryCategory salaryCategory;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "employee_block", length = 16)
    private EmployeeSalaryBlock employeeBlock;

    @Column(length = 200)
    private String qualification;

    /** Nhóm hệ số (legacy): 1 → Đại học, 2 → Cao đẳng, 3 → Lao động phổ thông */
    @Column(name = "tier_group", nullable = false)
    @Builder.Default
    private int tierGroup = 3;

    @Column(name = "doctor_qualification_code", length = 32)
    private String doctorQualificationCode;

    @Column(name = "qualification_note", length = 200)
    private String qualificationNote;

    /** Thời gian chuyển đổi bằng cấp (bác sỹ), đơn vị năm */
    @Column(name = "degree_conversion_years", nullable = false, precision = 6, scale = 3)
    @Builder.Default
    private BigDecimal degreeConversionYears = BigDecimal.ZERO;

    /** Thời hạn nâng lương trước / tổng quy đổi (năm) — đồng bộ từ {@link #earlyRaiseConversions}. */
    @Column(name = "prior_raise_years", nullable = false, precision = 6, scale = 3)
    @Builder.Default
    private BigDecimal priorRaiseYears = BigDecimal.ZERO;

    /**
     * Chi tiết quy đổi nâng lương sớm: [{raiseDate, years}, …].
     * Tổng years → {@link #priorRaiseYears}.
     */
    @Convert(converter = EarlyRaiseConversionsConverter.class)
    @Column(name = "early_raise_conversions", columnDefinition = "TEXT")
    @Builder.Default
    private List<EarlyRaiseConversionDto> earlyRaiseConversions = new ArrayList<>();

    @Column(name = "professional_attraction_salary", nullable = false, precision = 14, scale = 2)
    @Builder.Default
    private BigDecimal professionalAttractionSalary = BigDecimal.ZERO;

    /** Ngày chốt thâm niên (vd. 30/06/2026 trong file nhân lực). */
    @Column(name = "seniority_as_of_date")
    private LocalDate seniorityAsOfDate;

    /** Thời gian bắt đầu tính thang bảng lương. */
    @Column(name = "salary_scale_start_date")
    private LocalDate salaryScaleStartDate;

    /**
     * Thâm niên (năm) tại {@link #seniorityAsOfDate}.
     * Từ mồng 1 mỗi tháng sau mốc này hệ thống cộng thêm 1/12.
     */
    @Column(name = "base_seniority_years", precision = 10, scale = 6)
    private BigDecimal baseSeniorityYears;

    /** LĐG — lương đóng góp / bậc cố định, không nhảy theo thang bảng lương. */
    @Column(name = "ldg", nullable = false)
    @Builder.Default
    private boolean ldg = false;

    /** Nhãn bậc cố định (vd. LĐG) khi {@link #ldg} = true. */
    @Column(name = "fixed_grade_label", length = 64)
    private String fixedGradeLabel;

    /** Lương đóng BH / cơ bản — import từ file nhân lực. */
    @Column(name = "imported_insurance_salary", precision = 14, scale = 2)
    private BigDecimal importedInsuranceSalary;

    /** Lương đảm bảo sản phẩm — import từ file nhân lực. */
    @Column(name = "imported_product_salary", precision = 14, scale = 2)
    private BigDecimal importedProductSalary;

    @Column(name = "last_notified_grade", nullable = false)
    @Builder.Default
    private int lastNotifiedGrade = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }
}
