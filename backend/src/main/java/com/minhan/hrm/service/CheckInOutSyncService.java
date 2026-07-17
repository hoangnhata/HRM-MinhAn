package com.minhan.hrm.service;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.dto.attendance.CheckInOutSyncStatusDto;
import com.minhan.hrm.exception.ApiException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
@Slf4j
public class CheckInOutSyncService {

    private static final Pattern SAFE_TABLE = Pattern.compile("^[A-Za-z0-9_.\\[\\]]+$");

    private final HrmProperties hrmProperties;
    private final CheckInOutImportService checkInOutImportService;
    private final ChamcongSyncConfigService chamcongSyncConfigService;

    @Autowired(required = false)
    @Qualifier("chamcongJdbcTemplate")
    private JdbcTemplate chamcongJdbc;

    private final AtomicReference<CheckInOutSyncStatusDto> lastStatus =
            new AtomicReference<>(CheckInOutSyncStatusDto.builder()
                    .enabled(false)
                    .connected(false)
                    .build());

    public CheckInOutSyncStatusDto getStatus() {
        HrmProperties.Chamcong cfg = hrmProperties.getChamcong();
        CheckInOutSyncStatusDto prev = lastStatus.get();
        boolean connected = cfg.isEnabled() && testConnection();
        var schedule = chamcongSyncConfigService.getConfig();
        return CheckInOutSyncStatusDto.builder()
                .enabled(cfg.isEnabled())
                .connected(connected)
                .autoSyncEnabled(schedule.isAutoSyncEnabled())
                .autoSyncTime(chamcongSyncConfigService.formatSyncTime(schedule))
                .autoSyncIntervalMinutes(chamcongSyncConfigService.resolveIntervalMinutes(schedule))
                .lastAutoSyncAt(schedule.getLastAutoSyncAt())
                .lastSyncAt(prev.getLastSyncAt())
                .lastFromDate(prev.getLastFromDate())
                .lastMessage(prev.getLastMessage())
                .lastResult(prev.getLastResult())
                .build();
    }

    public CheckInOutSyncStatusDto updateSchedule(com.minhan.hrm.dto.attendance.ChamcongSyncScheduleUpdateRequest req) {
        chamcongSyncConfigService.updateSchedule(req);
        return getStatus();
    }

    public Map<String, Object> syncRecent() {
        int lookback = Math.max(1, hrmProperties.getChamcong().getLookbackDays());
        return syncFromDate(LocalDate.now().minusDays(lookback));
    }

    /** Đồng bộ tự động theo chu kỳ — lookback ngắn để nhanh. */
    public Map<String, Object> syncRecentForAuto() {
        int lookback = Math.max(1, hrmProperties.getChamcong().getAutoLookbackDays());
        return syncFromDate(LocalDate.now().minusDays(lookback));
    }

    public Map<String, Object> syncFromDate(LocalDate fromDate) {
        requireEnabled();
        if (fromDate == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "fromDate bắt buộc");
        }

        List<CheckInOutImportService.PunchRow> punches = fetchPunches(fromDate);
        log.info("Đồng bộ máy chấm công từ {}: {} lượt quẹt", fromDate, punches.size());

        Map<String, Object> result = checkInOutImportService.importPunches(punches);
        result = new java.util.LinkedHashMap<>(result);
        result.put("fromDate", fromDate.toString());
        result.put("source", "sqlserver");

        lastStatus.set(CheckInOutSyncStatusDto.builder()
                .enabled(true)
                .connected(true)
                .lastSyncAt(LocalDateTime.now())
                .lastFromDate(fromDate)
                .lastMessage("Đồng bộ thành công")
                .lastResult(result)
                .build());

        return result;
    }

    private List<CheckInOutImportService.PunchRow> fetchPunches(LocalDate fromDate) {
        String table = resolveTableName();
        String sql = "SELECT UserEnrollNumber, TimeStr FROM " + table + " WHERE TimeDate >= ? ORDER BY TimeStr";

        try {
            return chamcongJdbc.query(
                    sql,
                    (rs, rowNum) -> {
                        int enroll = rs.getInt("UserEnrollNumber");
                        Timestamp ts = rs.getTimestamp("TimeStr");
                        LocalDateTime time = ts != null ? ts.toLocalDateTime() : null;
                        return new CheckInOutImportService.PunchRow(enroll, time);
                    },
                    fromDate);
        } catch (Exception e) {
            log.error("Không đọc được dữ liệu từ SQL Server chamcong", e);
            lastStatus.set(CheckInOutSyncStatusDto.builder()
                    .enabled(true)
                    .connected(false)
                    .lastSyncAt(LocalDateTime.now())
                    .lastFromDate(fromDate)
                    .lastMessage("Lỗi kết nối/đọc SQL Server: " + e.getMessage())
                    .build());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Không kết nối được máy chấm công: " + e.getMessage());
        }
    }

    private String resolveTableName() {
        String table = hrmProperties.getChamcong().getTable();
        if (table == null || table.isBlank() || !SAFE_TABLE.matcher(table.trim()).matches()) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Cấu hình bảng chamcong không hợp lệ");
        }
        return table.trim();
    }

    private void requireEnabled() {
        if (!hrmProperties.getChamcong().isEnabled() || chamcongJdbc == null) {
            throw new ApiException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "Chưa bật đồng bộ máy chấm công. Đặt CHAMCONG_ENABLED=true và cấu hình kết nối SQL Server.");
        }
    }

    private boolean testConnection() {
        if (chamcongJdbc == null) {
            return false;
        }
        try {
            chamcongJdbc.queryForObject("SELECT 1", Integer.class);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
