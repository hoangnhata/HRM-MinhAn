package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalTime;

@Entity
@Table(name = "attendance_shift_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceShiftConfig {

    @Id
    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(length = 16)
    private AttendanceShiftSeason season;

    @Column(name = "morning_start", nullable = false)
    private LocalTime morningStart;

    @Column(name = "morning_end", nullable = false)
    private LocalTime morningEnd;

    @Column(name = "afternoon_start", nullable = false)
    private LocalTime afternoonStart;

    @Column(name = "afternoon_end", nullable = false)
    private LocalTime afternoonEnd;

    /** Giờ vào đầu ngày ca thông tầm (độc lập ca sáng/chiều). */
    @Column(name = "continuous_start", nullable = false)
    private LocalTime continuousStart;

    /** Giờ ra cuối ngày ca thông tầm. */
    @Column(name = "continuous_end", nullable = false)
    private LocalTime continuousEnd;

    @Column(name = "morning_units", nullable = false, precision = 10, scale = 8)
    private BigDecimal morningUnits;

    @Column(name = "afternoon_units", nullable = false, precision = 10, scale = 8)
    private BigDecimal afternoonUnits;

    @Column(name = "morning_in_before_min", nullable = false)
    private Integer morningInBeforeMin = 60;

    @Column(name = "morning_in_after_min", nullable = false)
    private Integer morningInAfterMin = 120;

    @Column(name = "morning_out_before_min", nullable = false)
    private Integer morningOutBeforeMin = 60;

    @Column(name = "morning_out_after_min", nullable = false)
    private Integer morningOutAfterMin = 30;

    @Column(name = "afternoon_in_before_min", nullable = false)
    private Integer afternoonInBeforeMin = 30;

    @Column(name = "afternoon_in_after_min", nullable = false)
    private Integer afternoonInAfterMin = 60;

    @Column(name = "afternoon_out_before_min", nullable = false)
    private Integer afternoonOutBeforeMin = 60;

    @Column(name = "afternoon_out_after_min", nullable = false)
    private Integer afternoonOutAfterMin = 60;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }
}
