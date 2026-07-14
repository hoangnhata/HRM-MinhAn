package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "salary_scale_entry")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalaryScaleEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "scale_type", nullable = false, length = 32)
    private SalaryScaleType scaleType;

    @Column(nullable = false, length = 200)
    private String qualification;

    @Column(name = "grade_level", nullable = false)
    private int gradeLevel;

    @Column(name = "seniority_from", nullable = false, precision = 6, scale = 3)
    private BigDecimal seniorityFrom;

    @Column(name = "seniority_to", precision = 6, scale = 3)
    private BigDecimal seniorityTo;

    @Column(nullable = false, precision = 8, scale = 4)
    private BigDecimal coefficient;

    @Column(name = "base_insurance_salary", nullable = false, precision = 14, scale = 2)
    private BigDecimal baseInsuranceSalary;

    @Column(name = "product_salary", nullable = false, precision = 14, scale = 2)
    private BigDecimal productSalary;

    @Column(name = "total_income", nullable = false, precision = 14, scale = 2)
    private BigDecimal totalIncome;

    @Column(name = "updated_at")
    private Instant updatedAt;
}
