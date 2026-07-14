package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

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

    /** Thời hạn nâng lương trước, đơn vị năm */
    @Column(name = "prior_raise_years", nullable = false, precision = 6, scale = 3)
    @Builder.Default
    private BigDecimal priorRaiseYears = BigDecimal.ZERO;

    @Column(name = "professional_attraction_salary", nullable = false, precision = 14, scale = 2)
    @Builder.Default
    private BigDecimal professionalAttractionSalary = BigDecimal.ZERO;

    /** Ngày chốt thâm niên (theo file thâm niên nv.xlsx). */
    @Column(name = "seniority_as_of_date")
    private LocalDate seniorityAsOfDate;

    /** Lương đóng BH / cơ bản — import từ thâm niên nv.xlsx. */
    @Column(name = "imported_insurance_salary", precision = 14, scale = 2)
    private BigDecimal importedInsuranceSalary;

    /** Lương đảm bảo sản phẩm — import từ thâm niên nv.xlsx. */
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
