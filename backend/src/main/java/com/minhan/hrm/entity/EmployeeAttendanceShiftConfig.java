package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalTime;

@Entity
@Table(
        name = "employee_attendance_shift_config",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_employee_shift_season",
                columnNames = {"employee_id", "season"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmployeeAttendanceShiftConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 16)
    private AttendanceShiftSeason season;

    @Column(name = "morning_start", nullable = false)
    private LocalTime morningStart;
    @Column(name = "morning_end", nullable = false)
    private LocalTime morningEnd;
    @Column(name = "afternoon_start", nullable = false)
    private LocalTime afternoonStart;
    @Column(name = "afternoon_end", nullable = false)
    private LocalTime afternoonEnd;
    @Column(name = "continuous_start", nullable = false)
    private LocalTime continuousStart;
    @Column(name = "continuous_end", nullable = false)
    private LocalTime continuousEnd;

    @Column(name = "morning_units", nullable = false, precision = 10, scale = 8)
    private BigDecimal morningUnits;
    @Column(name = "afternoon_units", nullable = false, precision = 10, scale = 8)
    private BigDecimal afternoonUnits;

    @Column(name = "morning_in_before_min", nullable = false)
    private Integer morningInBeforeMin;
    @Column(name = "morning_in_after_min", nullable = false)
    private Integer morningInAfterMin;
    @Column(name = "morning_out_before_min", nullable = false)
    private Integer morningOutBeforeMin;
    @Column(name = "morning_out_after_min", nullable = false)
    private Integer morningOutAfterMin;
    @Column(name = "afternoon_in_before_min", nullable = false)
    private Integer afternoonInBeforeMin;
    @Column(name = "afternoon_in_after_min", nullable = false)
    private Integer afternoonInAfterMin;
    @Column(name = "afternoon_out_before_min", nullable = false)
    private Integer afternoonOutBeforeMin;
    @Column(name = "afternoon_out_after_min", nullable = false)
    private Integer afternoonOutAfterMin;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    void touch() {
        updatedAt = Instant.now();
    }
}
