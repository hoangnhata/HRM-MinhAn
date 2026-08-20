package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalTime;

@Entity
@Table(name = "continuous_shift_type")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ContinuousShiftType {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100, unique = true)
    private String name;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private ContinuousShiftKind kind = ContinuousShiftKind.CONTINUOUS;

    /** Ca thông tầm: giờ vào đầu ngày. Ca sáng–chiều: đồng bộ = morningStart. */
    @Column(name = "start_time", nullable = false)
    private LocalTime startTime;

    /** Ca thông tầm: giờ ra cuối ngày. Ca sáng–chiều: đồng bộ = afternoonEnd. */
    @Column(name = "end_time", nullable = false)
    private LocalTime endTime;

    @Column(name = "morning_start")
    private LocalTime morningStart;

    @Column(name = "morning_end")
    private LocalTime morningEnd;

    @Column(name = "afternoon_start")
    private LocalTime afternoonStart;

    @Column(name = "afternoon_end")
    private LocalTime afternoonEnd;

    /** Cửa sổ check-in (thông tầm) / vào ca sáng (sáng–chiều). */
    @Column(name = "check_in_before_min", nullable = false)
    @Builder.Default
    private Integer checkInBeforeMin = 60;

    @Column(name = "check_in_after_min", nullable = false)
    @Builder.Default
    private Integer checkInAfterMin = 120;

    @Column(name = "check_out_before_min", nullable = false)
    @Builder.Default
    private Integer checkOutBeforeMin = 60;

    @Column(name = "check_out_after_min", nullable = false)
    @Builder.Default
    private Integer checkOutAfterMin = 60;

    @Column(name = "morning_out_before_min")
    private Integer morningOutBeforeMin;

    @Column(name = "morning_out_after_min")
    private Integer morningOutAfterMin;

    @Column(name = "afternoon_in_before_min")
    private Integer afternoonInBeforeMin;

    @Column(name = "afternoon_in_after_min")
    private Integer afternoonInAfterMin;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    public boolean isSplit() {
        return kind == ContinuousShiftKind.SPLIT;
    }

    public boolean isContinuous() {
        return kind == null || kind == ContinuousShiftKind.CONTINUOUS;
    }

    @PrePersist
    void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
        if (kind == null) {
            kind = ContinuousShiftKind.CONTINUOUS;
        }
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }
}
