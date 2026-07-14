package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "attendance_forgot_penalty_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceForgotPenaltyConfig {

    @Id
    private Long id;

    @Column(name = "tier1_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal tier1Amount;

    @Column(name = "tier2_min", nullable = false)
    private int tier2Min;

    @Column(name = "tier2_max", nullable = false)
    private int tier2Max;

    @Column(name = "tier2_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal tier2Amount;

    @Column(name = "tier3_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal tier3Amount;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    void touchUpdatedAt() {
        updatedAt = Instant.now();
    }
}
