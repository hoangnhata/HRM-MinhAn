package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AnnouncementCategory;
import com.minhan.hrm.entity.InternalAnnouncement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface InternalAnnouncementRepository extends JpaRepository<InternalAnnouncement, Long> {

    @Query("SELECT DISTINCT a FROM InternalAnnouncement a LEFT JOIN FETCH a.attachments WHERE (a.expiresAt IS NULL OR a.expiresAt > :now) AND (:category IS NULL OR a.category = :category) ORDER BY a.publishedAt DESC")
    List<InternalAnnouncement> findActiveWithAttachments(@Param("now") Instant now, @Param("category") AnnouncementCategory category);

    @Query("SELECT DISTINCT a FROM InternalAnnouncement a LEFT JOIN FETCH a.attachments WHERE a.id = :id")
    Optional<InternalAnnouncement> findByIdWithAttachments(@Param("id") Long id);
}
