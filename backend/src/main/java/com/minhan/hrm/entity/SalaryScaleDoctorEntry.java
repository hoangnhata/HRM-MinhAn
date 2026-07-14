package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = "salary_scale_doctor_entry")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalaryScaleDoctorEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "qualification_code", nullable = false, length = 32)
    private String qualificationCode;

    @Column(name = "qualification_name", nullable = false, length = 200)
    private String qualificationName;

    @Column(name = "time_label", nullable = false, length = 64)
    private String timeLabel;

    @Column(name = "years_min", nullable = false, precision = 6, scale = 3)
    private BigDecimal yearsMin;

    @Column(name = "years_max", precision = 6, scale = 3)
    private BigDecimal yearsMax;

    @Column(name = "total_salary", nullable = false, precision = 14, scale = 2)
    private BigDecimal totalSalary;

    @Column(name = "sort_order", nullable = false)
    @Builder.Default
    private int sortOrder = 0;
}
