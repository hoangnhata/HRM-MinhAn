package com.minhan.hrm.dto.attendance;

import lombok.Builder;
import lombok.Value;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Map;

@Value
@Builder
public class CheckInOutSyncStatusDto {
    boolean enabled;
    boolean connected;
    boolean autoSyncEnabled;
    String autoSyncTime;
    int autoSyncIntervalMinutes;
    LocalDateTime lastAutoSyncAt;
    LocalDateTime lastSyncAt;
    LocalDate lastFromDate;
    String lastMessage;
    Map<String, Object> lastResult;
}
