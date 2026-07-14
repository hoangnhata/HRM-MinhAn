package com.minhan.hrm.service;

import com.minhan.hrm.dto.attendance.ChamcongSyncScheduleUpdateRequest;
import com.minhan.hrm.entity.AttendanceChamcongSyncConfig;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.AttendanceChamcongSyncConfigRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

@Service
@RequiredArgsConstructor
public class ChamcongSyncConfigService {

    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HH:mm");

    private final AttendanceChamcongSyncConfigRepository repository;

    @Transactional(readOnly = true)
    public AttendanceChamcongSyncConfig getConfig() {
        return repository
                .findById(AttendanceChamcongSyncConfig.SINGLETON_ID)
                .orElseGet(this::createDefault);
    }

    @Transactional
    public AttendanceChamcongSyncConfig updateSchedule(ChamcongSyncScheduleUpdateRequest req) {
        LocalTime time = LocalTime.parse(req.getSyncTime(), TIME_FMT);
        AttendanceChamcongSyncConfig cfg = getConfig();
        cfg.setAutoSyncEnabled(Boolean.TRUE.equals(req.getAutoSyncEnabled()));
        cfg.setAutoSyncHour(time.getHour());
        cfg.setAutoSyncMinute(time.getMinute());
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

    public boolean matchesNow(AttendanceChamcongSyncConfig cfg, LocalDateTime now) {
        return cfg.isAutoSyncEnabled()
                && now.getHour() == cfg.getAutoSyncHour()
                && now.getMinute() == cfg.getAutoSyncMinute();
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
