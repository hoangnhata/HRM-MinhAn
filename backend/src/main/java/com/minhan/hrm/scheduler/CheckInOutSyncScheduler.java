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
 * Mỗi phút kiểm tra — nếu bật tự động thì đồng bộ theo chu kỳ (mặc định mỗi 1 phút).
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
        if (!chamcongSyncConfigService.isDue(cfg, now)) {
            return;
        }
        if (chamcongSyncConfigService.alreadyRanThisMinute(cfg, now)) {
            return;
        }

        try {
            // Đồng bộ gần đây (2 ngày) để nhanh; đủ bắt chấm mới trong ngày
            Map<String, Object> result = checkInOutSyncService.syncRecentForAuto();
            chamcongSyncConfigService.markAutoSyncRan(now);
            log.info(
                    "Tự động đồng bộ máy chấm công (mỗi {} phút): {}",
                    chamcongSyncConfigService.resolveIntervalMinutes(cfg),
                    result);
        } catch (Exception e) {
            log.error("Tự động đồng bộ máy chấm công thất bại", e);
        }
    }
}
