package com.minhan.hrm.dto.notification;

import com.minhan.hrm.entity.NotificationCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class AdhocNotificationRequest {

    @NotNull
    private Long targetUserId;

    private NotificationCategory category;

    @NotBlank
    private String title;

    @NotBlank
    private String message;

    private Long relatedEmployeeId;
}
