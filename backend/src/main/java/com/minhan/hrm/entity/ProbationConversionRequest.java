package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "probation_conversion_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProbationConversionRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "official_date", nullable = false)
    private LocalDate officialDate;

    @Column(nullable = false, length = 1000)
    private String reason;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "form_type", nullable = false, length = 16)
    private ProbationFormType formType;

    @Column(name = "mentor_comment", length = 2000)
    private String mentorComment;

    @Column(name = "head_dept_comment", length = 2000)
    private String headDeptComment;

    @Column(name = "ward_nurse_head_comment", length = 2000)
    private String wardNurseHeadComment;

    @Column(name = "hospital_nurse_head_comment", length = 2000)
    private String hospitalNurseHeadComment;

    @Column(name = "scores_json", columnDefinition = "TEXT")
    private String scoresJson;

    @Column(name = "total_score")
    private Integer totalScore;

    @Column(name = "max_score")
    private Integer maxScore;

    @Column(name = "grade_label", length = 64)
    private String gradeLabel;

    @Column(name = "hr_docs_complete", length = 16)
    private String hrDocsComplete;

    @Column(name = "hr_docs_note", length = 500)
    private String hrDocsNote;

    @Column(name = "hr_training_joined", length = 16)
    private String hrTrainingJoined;

    @Column(name = "hr_rule_compliance", length = 16)
    private String hrRuleCompliance;

    @Column(name = "hr_dept_feedback", length = 16)
    private String hrDeptFeedback;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "hr_proposal", length = 32)
    private ProbationHrProposal hrProposal;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 32)
    private ProbationConversionStatus status;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requested_by_user_id", nullable = false)
    private UserAccount requestedBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "nursing_head_reviewer_id")
    private UserAccount nursingHeadReviewer;

    @Column(name = "nursing_head_reviewed_at")
    private Instant nursingHeadReviewedAt;

    @Column(name = "nursing_head_comment", length = 1000)
    private String nursingHeadComment;

    @Column(name = "nursing_head_signature_path", length = 500)
    private String nursingHeadSignaturePath;

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

    @Column(name = "applied_at")
    private Instant appliedAt;

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
