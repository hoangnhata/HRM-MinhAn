package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "announcement_attachments")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AnnouncementAttachment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "announcement_id", nullable = false)
    private InternalAnnouncement announcement;

    @Column(name = "original_name", nullable = false)
    private String originalName;

    @Column(name = "stored_path", nullable = false, length = 500)
    private String storedPath;

    @Column(name = "content_type")
    private String contentType;

    @Column(name = "link_label", nullable = false, length = 64)
    @Builder.Default
    private String linkLabel = "tại đây";

    @Column(name = "sort_order", nullable = false)
    @Builder.Default
    private int sortOrder = 0;
}
