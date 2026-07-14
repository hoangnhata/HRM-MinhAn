package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "duty_shift_entry")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DutyShiftEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(name = "shift_type_code", nullable = false, length = 32)
    private String shiftTypeCode;

    @Column(name = "role_tier", nullable = false, length = 32)
    private String roleTier;

    @Column(name = "bonus_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal bonusAmount;

    @Column(name = "work_units", nullable = false, precision = 10, scale = 8)
    private BigDecimal workUnits;

    @Column(name = "post_duty_pay", nullable = false, precision = 15, scale = 2)
    private BigDecimal postDutyPay;

    @Column(length = 500)
    private String note;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "entered_by_user_id")
    private UserAccount enteredBy;

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
