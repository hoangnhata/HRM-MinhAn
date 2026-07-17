package com.minhan.hrm.dto.notification;

import com.minhan.hrm.entity.NotificationCategory;
import lombok.Builder;
import lombok.Value;

import java.time.Instant;

@Value
@Builder
public class NotificationDto {
    Long id;
    NotificationCategory category;
    String title;
    String message;
    boolean read;
    Instant createdAt;
    Long relatedEmployeeId;
    /** Legacy FK — announcement feature removed; kept for existing DB rows */
    Long relatedAnnouncementId;
    /** Bảng lương/công/lương đột xuất — hiển thị cảnh báo bảo mật phía client */
    boolean sensitive;
    /** Đường dẫn SPA khi bấm thông báo (ví dụ /work?tab=requests). */
    String actionPath;
}
