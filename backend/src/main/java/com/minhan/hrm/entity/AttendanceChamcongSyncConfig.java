package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDateTime;

@Entity
@Table(name = "attendance_chamcong_sync_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceChamcongSyncConfig {

    public static final long SINGLETON_ID = 1L;

    @Id
    private Long id;

    @Column(name = "auto_sync_enabled", nullable = false)
    private boolean autoSyncEnabled;

    @Column(name = "auto_sync_hour", nullable = false)
    private int autoSyncHour;

    @Column(name = "auto_sync_minute", nullable = false)
    private int autoSyncMinute;

    /** Chu kỳ tự đồng bộ (phút). 1 = mỗi phút khi backend chạy. */
    @Column(name = "auto_sync_interval_minutes", nullable = false)
    @Builder.Default
    private int autoSyncIntervalMinutes = 1;

    @Column(name = "last_auto_sync_at")
    private LocalDateTime lastAutoSyncAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    void touchUpdatedAt() {
        updatedAt = Instant.now();
    }
}
