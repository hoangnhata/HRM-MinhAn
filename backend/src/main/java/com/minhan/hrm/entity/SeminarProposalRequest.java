package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "seminar_proposal_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SeminarProposalRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "proposing_department", nullable = false, length = 255)
    private String proposingDepartment;

    @Column(name = "seminar_name", nullable = false, length = 500)
    private String seminarName;

    @Column(nullable = false, length = 500)
    private String location;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    /** Phạm vi được tính hội thảo; đơn nhiều ngày luôn là FULL_DAY. */
    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "attendance_scope", nullable = false, length = 32)
    @Builder.Default
    private AttendanceShiftScope attendanceScope = AttendanceShiftScope.FULL_DAY;

    @Column(nullable = false, length = 2000)
    private String reason;

    @Column(name = "employee_commitment_ack", nullable = false)
    private boolean employeeCommitmentAck;

    @Column(name = "department_commitment_ack", nullable = false)
    private boolean departmentCommitmentAck;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 32)
    private SeminarProposalStatus status;

    /**
     * true = duyệt có công (công bình thường + trạng thái Hội thảo);
     * false = duyệt không công (0 công + trạng thái Hội thảo).
     * null khi chưa duyệt.
     */
    @Column(name = "with_pay")
    private Boolean withPay;

    /** Số tiền hỗ trợ hội thảo — Giám đốc nhập khi duyệt (null = không cấp). */
    @Column(name = "support_amount", length = 255)
    private String supportAmount;

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
