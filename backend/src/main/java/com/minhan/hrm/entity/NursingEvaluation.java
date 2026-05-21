package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "nursing_evaluations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NursingEvaluation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "evaluator_user_id", nullable = false)
    private UserAccount evaluator;

    @Column(name = "period_year", nullable = false)
    private Integer periodYear;

    @Column(name = "period_month", nullable = false)
    private Integer periodMonth;

    @Column(name = "template_code", nullable = false, length = 64)
    private String templateCode;

    @Column(name = "scores_json", nullable = false, columnDefinition = "TEXT")
    private String scoresJson;

    @Column(name = "total_self", precision = 8, scale = 2)
    private BigDecimal totalSelf;

    @Column(name = "total_truong_khoa", precision = 8, scale = 2)
    private BigDecimal totalTruongKhoa;

    @Column(name = "total_ddt", precision = 8, scale = 2)
    private BigDecimal totalDdt;

    @Column(name = "grade_self", length = 64)
    private String gradeSelf;

    @Column(name = "grade_truong_khoa", length = 64)
    private String gradeTruongKhoa;

    @Column(name = "grade_ddt", length = 64)
    private String gradeDdt;

    @Column(columnDefinition = "TEXT")
    private String comments;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
    }
}
