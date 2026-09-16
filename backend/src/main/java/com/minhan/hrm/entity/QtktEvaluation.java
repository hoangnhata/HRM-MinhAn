package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(
        name = "qtkt_evaluations",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_qtkt_emp_proc_date_ctx_patient",
                columnNames = {"employee_id", "procedure_code", "eval_date", "check_context_code", "patient_code"}
        )
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QtktEvaluation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "department_id", nullable = false)
    private Department department;

    @Column(name = "procedure_code", nullable = false, length = 64)
    private String procedureCode;

    @Column(name = "procedure_name", nullable = false)
    private String procedureName;

    /** Mã lựa chọn kiểm tra (vd. thời điểm rửa tay); rỗng nếu quy trình không yêu cầu. */
    @Column(name = "check_context_code", nullable = false, length = 64)
    @Builder.Default
    private String checkContextCode = "";

    @Column(name = "check_context_label")
    private String checkContextLabel;

    /** Mã bệnh nhân — bắt buộc với phiếu tư vấn GDSK; rỗng với quy trình khác. */
    @Column(name = "patient_code", nullable = false, length = 64)
    @Builder.Default
    private String patientCode = "";

    @Column(name = "eval_date", nullable = false)
    private LocalDate evalDate;

    /** JSON map stepId -> điểm đạt */
    @Column(name = "scores_json", nullable = false, columnDefinition = "TEXT")
    @Builder.Default
    private String scoresJson = "{}";

    @Column(name = "total_score", nullable = false, precision = 6, scale = 2)
    @Builder.Default
    private BigDecimal totalScore = BigDecimal.ZERO;

    @Column(name = "max_score", nullable = false, precision = 6, scale = 2)
    @Builder.Default
    private BigDecimal maxScore = BigDecimal.TEN;

    @Column(columnDefinition = "TEXT")
    private String note;

    /** Bản ghi seed demo — xóa khi DEMO_SEED_CLEANUP=true. */
    @Column(name = "is_demo", nullable = false)
    @Builder.Default
    private boolean demo = false;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 32)
    @Builder.Default
    private QtktEvaluationStatus status = QtktEvaluationStatus.DRAFT;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_id")
    private UserAccount createdBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "updated_by_id")
    private UserAccount updatedBy;

    @Column(name = "submitted_at")
    private Instant submittedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        if (createdAt == null) createdAt = now;
        if (updatedAt == null) updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
