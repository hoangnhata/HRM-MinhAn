package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

/** Một phiên bản mẫu đánh giá NV khối ĐD (bản mới nhất theo version = mẫu đang dùng). */
@Entity
@Table(name = "nursing_evaluation_template_revisions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NursingEvaluationTemplateRevision {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "template_code", nullable = false, length = 64)
    private String templateCode;

    @Column(nullable = false)
    private Integer version;

    @Column(name = "template_json", nullable = false, columnDefinition = "MEDIUMTEXT")
    private String templateJson;

    @Column(name = "change_note", length = 500)
    private String changeNote;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_id")
    private UserAccount createdBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
    }
}
