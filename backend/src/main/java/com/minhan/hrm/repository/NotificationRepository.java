package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Notification;
import com.minhan.hrm.entity.UserAccount;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    @EntityGraph(attributePaths = {"relatedEmployee", "relatedAnnouncement"})
    List<Notification> findByUserOrderByCreatedAtDesc(UserAccount user);

    long countByUserAndOpenedFalse(UserAccount user);

    @Modifying
    @Query("UPDATE Notification n SET n.relatedEmployee = NULL WHERE n.relatedEmployee.id = :employeeId")
    void clearRelatedEmployee(@Param("employeeId") Long employeeId);

    void deleteByUser_Id(Long userId);
}
