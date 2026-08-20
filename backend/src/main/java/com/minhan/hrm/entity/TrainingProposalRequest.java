package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "training_proposal_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrainingProposalRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "proposing_department", nullable = false, length = 255)
    private String proposingDepartment;

    @Column(name = "course_name", nullable = false, length = 500)
    private String courseName;

    @Column(nullable = false, length = 500)
    private String location;

    @Column(name = "planned_period", nullable = false, length = 255)
    private String plannedPeriod;

    @Column(name = "start_date")
    private LocalDate startDate;

    @Column(name = "end_date")
    private LocalDate endDate;

    @Column(name = "tuition_fee", length = 255)
    private String tuitionFee;

    /** Tiền hỗ trợ hàng tháng — HCNS nhập khi duyệt. */
    @Column(name = "monthly_support", length = 255)
    private String monthlySupport;

    /** Thời gian cam kết sau khóa học — HCNS nhập khi duyệt. */
    @Column(name = "post_course_commitment", length = 255)
    private String postCourseCommitment;

    @Column(name = "training_goal", nullable = false, length = 2000)
    private String trainingGoal;

    @Column(nullable = false, length = 2000)
    private String reason;

    @Column(name = "employee_commitment_ack", nullable = false)
    private boolean employeeCommitmentAck;

    @Column(name = "department_commitment_ack", nullable = false)
    private boolean departmentCommitmentAck;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 32)
    private TrainingProposalStatus status;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requested_by_user_id", nullable = false)
    private UserAccount requestedBy;

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
