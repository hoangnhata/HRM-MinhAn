package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Notification;
import com.minhan.hrm.entity.UserAccount;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    @EntityGraph(attributePaths = {"relatedEmployee", "relatedAnnouncement"})
    List<Notification> findByUserOrderByCreatedAtDesc(UserAccount user);

    long countByUserAndOpenedFalse(UserAccount user);
}
