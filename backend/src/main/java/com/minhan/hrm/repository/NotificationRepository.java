package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Notification;
import com.minhan.hrm.entity.NotificationCategory;
import com.minhan.hrm.entity.UserAccount;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    @EntityGraph(attributePaths = {"relatedEmployee", "relatedAnnouncement"})
    List<Notification> findByUserOrderByCreatedAtDesc(UserAccount user);

    /** Một trang thông báo; thứ tự sắp xếp do Pageable quyết định (chưa đọc trước, mới trước). */
    @EntityGraph(attributePaths = {"relatedEmployee", "relatedAnnouncement"})
    Page<Notification> findByUser(UserAccount user, Pageable pageable);

    /** Chỉ các thông báo chưa đọc — tập nhỏ, dùng khi phải lọc thêm theo phạm vi trong bộ nhớ. */
    @EntityGraph(attributePaths = {"relatedEmployee"})
    List<Notification> findByUserAndOpenedFalse(UserAccount user);

    long countByUserAndOpenedFalse(UserAccount user);

    @Modifying
    @Query("UPDATE Notification n SET n.opened = true WHERE n.user = :user AND n.opened = false")
    int markAllOpened(@Param("user") UserAccount user);

    /** Dọn thông báo đã đọc quá hạn lưu — chạy theo lịch đêm. */
    @Modifying
    @Query("DELETE FROM Notification n WHERE n.opened = true AND n.createdAt < :before")
    int deleteOpenedBefore(@Param("before") Instant before);

    long countByUser_IdAndOpenedFalse(Long userId);

    @Modifying
    @Query("UPDATE Notification n SET n.relatedEmployee = NULL WHERE n.relatedEmployee.id = :employeeId")
    void clearRelatedEmployee(@Param("employeeId") Long employeeId);

    void deleteByUser_Id(Long userId);

    void deleteByCategoryAndRelatedRequestId(NotificationCategory category, Long relatedRequestId);
}
