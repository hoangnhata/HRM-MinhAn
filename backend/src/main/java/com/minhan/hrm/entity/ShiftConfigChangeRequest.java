package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalTime;

@Entity
@Table(name = "shift_config_change_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ShiftConfigChangeRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 16)
    private ShiftConfigChangeSeason season;

    /** Ca sáng/chiều — mùa hè (hoặc mùa duy nhất khi SUMMER/WINTER). */
    @Column(name = "morning_start", nullable = false)
    private LocalTime morningStart;

    @Column(name = "morning_end", nullable = false)
    private LocalTime morningEnd;

    @Column(name = "afternoon_start", nullable = false)
    private LocalTime afternoonStart;

    @Column(name = "afternoon_end", nullable = false)
    private LocalTime afternoonEnd;

    /** Ca sáng/chiều mùa đông — bắt buộc khi season = BOTH. */
    @Column(name = "winter_morning_start")
    private LocalTime winterMorningStart;

    @Column(name = "winter_morning_end")
    private LocalTime winterMorningEnd;

    @Column(name = "winter_afternoon_start")
    private LocalTime winterAfternoonStart;

    @Column(name = "winter_afternoon_end")
    private LocalTime winterAfternoonEnd;

    @Column(name = "morning_units", nullable = false, precision = 10, scale = 8)
    private BigDecimal morningUnits;

    @Column(name = "afternoon_units", nullable = false, precision = 10, scale = 8)
    private BigDecimal afternoonUnits;

    @Column(length = 1000)
    private String reason;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 32)
    private ShiftConfigChangeRequestStatus status;

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
