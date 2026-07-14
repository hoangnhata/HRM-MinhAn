package com.minhan.hrm.scheduler;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.entity.AttendanceChamcongSyncConfig;
import com.minhan.hrm.service.ChamcongSyncConfigService;
import com.minhan.hrm.service.CheckInOutSyncService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * Mỗi phút kiểm tra giờ hẹn — đến đúng HH:mm thì tự đồng bộ 7 ngày gần nhất.
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "minhan.hrm.chamcong", name = "enabled", havingValue = "true")
public class CheckInOutSyncScheduler {

    private final HrmProperties hrmProperties;
    private final CheckInOutSyncService checkInOutSyncService;
    private final ChamcongSyncConfigService chamcongSyncConfigService;

    @Scheduled(cron = "0 * * * * *")
    public void runScheduledSyncIfDue() {
        if (!hrmProperties.getChamcong().isEnabled()) {
            return;
        }
        LocalDateTime now = LocalDateTime.now();
        AttendanceChamcongSyncConfig cfg = chamcongSyncConfigService.getConfig();
        if (!chamcongSyncConfigService.matchesNow(cfg, now)) {
            return;
        }
        if (chamcongSyncConfigService.alreadyRanThisMinute(cfg, now)) {
            return;
        }

        try {
            Map<String, Object> result = checkInOutSyncService.syncRecent();
            chamcongSyncConfigService.markAutoSyncRan(now);
            log.info("Tự động đồng bộ máy chấm công lúc {}: {}", chamcongSyncConfigService.formatSyncTime(cfg), result);
        } catch (Exception e) {
            log.error("Tự động đồng bộ máy chấm công thất bại", e);
        }
    }
}
