package com.minhan.hrm.scheduler;

import com.minhan.hrm.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;

/**
 * Mỗi đêm xoá thông báo đã đọc quá hạn lưu để bảng không phình vô hạn.
 * Thông báo chưa đọc luôn được giữ. Hạn lưu chỉnh bằng
 * {@code minhan.hrm.notifications.retention-days} (mặc định 90 ngày).
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NotificationCleanupScheduler {

    private final NotificationService notificationService;

    @Value("${minhan.hrm.notifications.retention-days:90}")
    private int retentionDays;

    @Scheduled(cron = "0 20 0 * * *")
    public void purgeOldReadNotifications() {
        if (retentionDays <= 0) {
            return;
        }
        Instant before = Instant.now().minus(Duration.ofDays(retentionDays));
        int removed = notificationService.purgeOpenedBefore(before);
        if (removed > 0) {
            log.info("Notification cleanup: removed {} read notification(s) older than {} days",
                    removed, retentionDays);
        }
    }
}
