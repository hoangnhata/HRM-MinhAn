package com.minhan.hrm.service;

import com.minhan.hrm.dto.attendance.ChamcongSyncScheduleUpdateRequest;
import com.minhan.hrm.entity.AttendanceChamcongSyncConfig;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.AttendanceChamcongSyncConfigRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

@Service
@RequiredArgsConstructor
public class ChamcongSyncConfigService {

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");
    private static final int DEFAULT_INTERVAL_MINUTES = 1;

    private final AttendanceChamcongSyncConfigRepository repository;

    @Transactional(readOnly = true)
    public AttendanceChamcongSyncConfig getConfig() {
        return repository
                .findById(AttendanceChamcongSyncConfig.SINGLETON_ID)
                .orElseGet(this::createDefault);
    }

    @Transactional
    public AttendanceChamcongSyncConfig updateSchedule(ChamcongSyncScheduleUpdateRequest req) {
        AttendanceChamcongSyncConfig cfg = getConfig();
        cfg.setAutoSyncEnabled(Boolean.TRUE.equals(req.getAutoSyncEnabled()));
        int interval = req.getIntervalMinutes() != null ? req.getIntervalMinutes() : DEFAULT_INTERVAL_MINUTES;
        cfg.setAutoSyncIntervalMinutes(Math.max(1, Math.min(60, interval)));
        if (req.getSyncTime() != null && !req.getSyncTime().isBlank()) {
            LocalTime time = LocalTime.parse(req.getSyncTime(), TIME_FMT);
            cfg.setAutoSyncHour(time.getHour());
            cfg.setAutoSyncMinute(time.getMinute());
        }
        return repository.save(cfg);
    }

    @Transactional
    public void markAutoSyncRan(LocalDateTime at) {
        AttendanceChamcongSyncConfig cfg = getConfig();
        cfg.setLastAutoSyncAt(at);
        repository.save(cfg);
    }

    public String formatSyncTime(AttendanceChamcongSyncConfig cfg) {
        return String.format("%02d:%02d", cfg.getAutoSyncHour(), cfg.getAutoSyncMinute());
    }

    public int resolveIntervalMinutes(AttendanceChamcongSyncConfig cfg) {
        int v = cfg.getAutoSyncIntervalMinutes();
        return v < 1 ? DEFAULT_INTERVAL_MINUTES : Math.min(60, v);
    }

    /** Đến hạn đồng bộ theo chu kỳ phút (không chờ giờ cố định trong ngày). */
    public boolean isDue(AttendanceChamcongSyncConfig cfg, LocalDateTime now) {
        if (!cfg.isAutoSyncEnabled()) {
            return false;
        }
        LocalDateTime last = cfg.getLastAutoSyncAt();
        if (last == null) {
            return true;
        }
        long elapsed = Duration.between(last, now).toMinutes();
        return elapsed >= resolveIntervalMinutes(cfg);
    }

    public boolean alreadyRanThisMinute(AttendanceChamcongSyncConfig cfg, LocalDateTime now) {
        LocalDateTime last = cfg.getLastAutoSyncAt();
        if (last == null) {
            return false;
        }
        return last.getYear() == now.getYear()
                && last.getMonth() == now.getMonth()
                && last.getDayOfMonth() == now.getDayOfMonth()
                && last.getHour() == now.getHour()
                && last.getMinute() == now.getMinute();
    }

    private AttendanceChamcongSyncConfig createDefault() {
        AttendanceChamcongSyncConfig cfg = AttendanceChamcongSyncConfig.builder()
                .id(AttendanceChamcongSyncConfig.SINGLETON_ID)
                .autoSyncEnabled(true)
                .autoSyncHour(1)
                .autoSyncMinute(30)
                .autoSyncIntervalMinutes(DEFAULT_INTERVAL_MINUTES)
                .build();
        try {
            return repository.save(cfg);
        } catch (Exception e) {
            return repository
                    .findById(AttendanceChamcongSyncConfig.SINGLETON_ID)
                    .orElseThrow(() -> new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tải cấu hình đồng bộ"));
        }
    }
}
