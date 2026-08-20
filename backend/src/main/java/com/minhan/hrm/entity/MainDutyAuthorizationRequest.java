package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "main_duty_authorization_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MainDutyAuthorizationRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "form_type", nullable = false, length = 16)
    private MainDutyFormType formType;

    @Column(name = "accompanying_from", nullable = false)
    private LocalDate accompanyingFrom;

    @Column(name = "accompanying_to", nullable = false)
    private LocalDate accompanyingTo;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(length = 50)
    private String phone;

    @Column(length = 500)
    private String address;

    @Column(length = 20)
    private String gender;

    @Column(length = 255)
    private String degree;

    @Column(length = 2000)
    private String reason;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 32)
    private MainDutyAuthorizationStatus status;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requested_by_user_id", nullable = false)
    private UserAccount requestedBy;

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
