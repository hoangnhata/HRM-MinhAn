package com.minhan.hrm.dto.notification;

import lombok.Builder;
import lombok.Value;

import java.util.List;

/** Một trang thông báo cho web/app tải dần thay vì kéo toàn bộ. */
@Value
@Builder
public class NotificationPageDto {
    List<NotificationDto> items;
    int page;
    int size;
    boolean hasMore;
    long total;
    long unread;
}
