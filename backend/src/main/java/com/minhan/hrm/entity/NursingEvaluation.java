package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

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

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 32)
    @Builder.Default
    private NursingEvaluationStatus status = NursingEvaluationStatus.DRAFT;

    @Column(name = "total_score", precision = 8, scale = 2)
    private BigDecimal totalScore;

    @Column(name = "overall_grade", length = 64)
    private String overallGrade;

    @Column(name = "evaluator_signature_path", length = 500)
    private String evaluatorSignaturePath;

    @Column(name = "evaluator_signed_at")
    private Instant evaluatorSignedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "head_reviewer_id")
    private UserAccount headReviewer;

    @Column(name = "head_reviewed_at")
    private Instant headReviewedAt;

    @Column(name = "head_comment", length = 1000)
    private String headComment;

    @Column(name = "head_signature_path", length = 500)
    private String headSignaturePath;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hr_reviewer_id")
    private UserAccount hrReviewer;

    @Column(name = "hr_reviewed_at")
    private Instant hrReviewedAt;

    @Column(name = "hr_comment", length = 1000)
    private String hrComment;

    @Column(name = "hr_signature_path", length = 500)
    private String hrSignaturePath;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "director_reviewer_id")
    private UserAccount directorReviewer;

    @Column(name = "director_reviewed_at")
    private Instant directorReviewedAt;

    @Column(name = "director_comment", length = 1000)
    private String directorComment;

    @Column(name = "director_signature_path", length = 500)
    private String directorSignaturePath;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
        if (status == null) {
            status = NursingEvaluationStatus.DRAFT;
        }
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }
}
