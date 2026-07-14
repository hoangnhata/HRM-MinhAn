package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;

@Entity
@Table(name = "attendance_work_request")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceWorkRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "request_type", nullable = false, length = 24)
    private AttendanceRequestType requestType;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    /** Ngày kết thúc (LEAVE / BUSINESS_TRIP). Null = chỉ một ngày (work_date). */
    @Column(name = "end_date")
    private LocalDate endDate;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "shift_scope", nullable = false, length = 16)
    private AttendanceShiftScope shiftScope;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "update_kind", length = 32)
    private AttendanceUpdateKind updateKind;

    @Column(nullable = false, length = 2000)
    private String reason;

    /** Địa điểm công tác (BUSINESS_TRIP). */
    @Column(name = "location", length = 255)
    private String location;

    @Column(name = "requested_start")
    private LocalTime requestedStart;

    @Column(name = "requested_end")
    private LocalTime requestedEnd;

    @Column(name = "requested_afternoon_start")
    private LocalTime requestedAfternoonStart;

    @Column(name = "requested_afternoon_end")
    private LocalTime requestedAfternoonEnd;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "explanation_kind", length = 24)
    private ExplanationKind explanationKind;

    @Column(name = "explained_time")
    private LocalTime explainedTime;

    @Column(name = "explained_departure_time")
    private LocalTime explainedDepartureTime;

    /** Giải trình từng mốc (tùy chọn) — ưu tiên hơn explainedTime / explainedDepartureTime. */
    @Column(name = "explained_morning_in")
    private LocalTime explainedMorningIn;

    @Column(name = "explained_morning_out")
    private LocalTime explainedMorningOut;

    @Column(name = "explained_afternoon_in")
    private LocalTime explainedAfternoonIn;

    @Column(name = "explained_afternoon_out")
    private LocalTime explainedAfternoonOut;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 32)
    private AttendanceRequestStatus status;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "head_reviewer_id")
    private UserAccount headReviewer;

    @Column(name = "head_reviewed_at")
    private Instant headReviewedAt;

    @Column(name = "head_comment", length = 500)
    private String headComment;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hr_reviewer_id")
    private UserAccount hrReviewer;

    @Column(name = "hr_reviewed_at")
    private Instant hrReviewedAt;

    @Column(name = "hr_comment", length = 500)
    private String hrComment;

    @Column(name = "hr_waive_forgot_fine", nullable = false)
    @Builder.Default
    private boolean hrWaiveForgotFine = false;

    /** Số lần trừ quên chấm khi duyệt (1 = thiếu một mốc, 2 = thiếu cả ca, 4 = cả ngày). */
    @Column(name = "forgot_fine_units")
    private Integer forgotFineUnits;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }
}
