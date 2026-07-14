package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "salary_scale_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalaryScaleConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "scale_type", nullable = false, unique = true, length = 32)
    private SalaryScaleType scaleType;

    @Column(name = "base_total_income", nullable = false, precision = 14, scale = 2)
    private BigDecimal baseTotalIncome;

    @Column(name = "base_insurance_salary", nullable = false, precision = 14, scale = 2)
    private BigDecimal baseInsuranceSalary;

    @Column(name = "base_product_salary", nullable = false, precision = 14, scale = 2)
    private BigDecimal baseProductSalary;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "updated_at")
    private Instant updatedAt;
}
