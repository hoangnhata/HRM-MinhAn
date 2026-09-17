package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(
        name = "nursing_daily_reports",
        uniqueConstraints = @UniqueConstraint(name = "uk_ndr_dept_date", columnNames = {"department_id", "report_date"})
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NursingDailyReport {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "department_id", nullable = false)
    private Department department;

    @Column(name = "report_date", nullable = false)
    private LocalDate reportDate;

    @Column(name = "total_staff", nullable = false)
    @Builder.Default
    private int totalStaff = 0;

    @Column(name = "working_staff", nullable = false)
    @Builder.Default
    private int workingStaff = 0;

    @Column(name = "planned_leave", nullable = false)
    @Builder.Default
    private int plannedLeave = 0;

    @Column(name = "unplanned_leave", nullable = false)
    @Builder.Default
    private int unplannedLeave = 0;

    @Column(name = "maternity_leave", nullable = false)
    @Builder.Default
    private int maternityLeave = 0;

    @Column(name = "long_leave", nullable = false)
    @Builder.Default
    private int longLeave = 0;

    @Column(name = "duty_afternoon_off", nullable = false)
    @Builder.Default
    private int dutyAfternoonOff = 0;

    @Column(name = "external_mission", nullable = false)
    @Builder.Default
    private int externalMission = 0;

    @Column(nullable = false)
    @Builder.Default
    private int inpatients = 0;

    /** NB nội trú theo cấp chăm sóc — tổng 3 cấp = {@link #inpatients}. */
    @Column(name = "inpatients_care_level1", nullable = false)
    @Builder.Default
    private int inpatientsCareLevel1 = 0;

    @Column(name = "inpatients_care_level2", nullable = false)
    @Builder.Default
    private int inpatientsCareLevel2 = 0;

    @Column(name = "inpatients_care_level3", nullable = false)
    @Builder.Default
    private int inpatientsCareLevel3 = 0;

    @Column(nullable = false)
    @Builder.Default
    private int outpatients = 0;

    @Column(nullable = false)
    @Builder.Default
    private int paraclinical = 0;

    @Column(nullable = false)
    @Builder.Default
    private int surgery = 0;

    @Column(name = "discharged_yesterday", nullable = false)
    @Builder.Default
    private int dischargedYesterday = 0;

    @Column(name = "actual_beds", nullable = false)
    @Builder.Default
    private int actualBeds = 0;

    @Column(name = "planned_beds", nullable = false)
    @Builder.Default
    private int plannedBeds = 0;

    @Column(name = "inpatient_treatment_days", nullable = false)
    @Builder.Default
    private int inpatientTreatmentDays = 0;

    @Column(nullable = false)
    @Builder.Default
    private int falls = 0;

    @Column(name = "new_pressure_ulcers", nullable = false)
    @Builder.Default
    private int newPressureUlcers = 0;

    @Column(name = "id_mixups", nullable = false)
    @Builder.Default
    private int idMixups = 0;

    @Column(name = "medication_errors", nullable = false)
    @Builder.Default
    private int medicationErrors = 0;

    /** Bản ghi seed demo — xóa khi DEMO_SEED_CLEANUP=true. */
    @Column(name = "is_demo", nullable = false)
    @Builder.Default
    private boolean demo = false;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private NursingDailyReportStatus status = NursingDailyReportStatus.SUBMITTED;

    @Column(name = "submitted_at")
    private Instant submittedAt;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "created_by_user_id", nullable = false)
    private UserAccount createdBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "updated_by_user_id")
    private UserAccount updatedBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
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
