package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "attendance_late_penalty_tier")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceLatePenaltyTier {

    @Id
    @Column(name = "sort_order")
    private int sortOrder;

    @Column(name = "min_minutes", nullable = false)
    private int minMinutes;

    @Column(name = "max_minutes")
    private Integer maxMinutes;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(name = "requires_discipline", nullable = false)
    private boolean requiresDiscipline;

    @Column(length = 255)
    private String note;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    void touchUpdatedAt() {
        updatedAt = Instant.now();
    }
}
