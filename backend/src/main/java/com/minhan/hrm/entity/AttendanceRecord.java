package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;

@Entity
@Table(name = "attendance_records")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(name = "check_in")
    private LocalTime checkIn;

    @Column(name = "check_out")
    private LocalTime checkOut;

    @Column(nullable = false, length = 32)
    private String status;

    @Column(length = 500)
    private String note;

    @Column(name = "morning_check_in")
    private LocalTime morningCheckIn;

    @Column(name = "morning_check_out")
    private LocalTime morningCheckOut;

    @Column(name = "afternoon_check_in")
    private LocalTime afternoonCheckIn;

    @Column(name = "afternoon_check_out")
    private LocalTime afternoonCheckOut;

    @Column(name = "morning_work_units", nullable = false, precision = 10, scale = 8)
    @Builder.Default
    private BigDecimal morningWorkUnits = BigDecimal.ZERO;

    @Column(name = "afternoon_work_units", nullable = false, precision = 10, scale = 8)
    @Builder.Default
    private BigDecimal afternoonWorkUnits = BigDecimal.ZERO;

    /** Công điều động ngoài ca (làm thêm ngoài giờ chính). */
    @Column(name = "overtime_work_units", nullable = false, precision = 10, scale = 8)
    @Builder.Default
    private BigDecimal overtimeWorkUnits = BigDecimal.ZERO;

    @Column(name = "late_minutes", nullable = false)
    @Builder.Default
    private int lateMinutes = 0;

    @Column(name = "late_minutes_exempt", nullable = false)
    @Builder.Default
    private boolean lateMinutesExempt = false;

    @Column(name = "forgot_shifts", length = 32)
    private String forgotShifts;

    @Column(name = "punch_times_json", columnDefinition = "TEXT")
    private String punchTimesJson;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
    }
}
