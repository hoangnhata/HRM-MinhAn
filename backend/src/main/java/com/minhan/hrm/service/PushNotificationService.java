package com.minhan.hrm.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.dto.notification.NotificationDto;
import com.minhan.hrm.entity.UserDeviceToken;
import com.minhan.hrm.repository.UserDeviceTokenRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class PushNotificationService {

    private final HrmProperties properties;
    private final UserDeviceTokenRepository deviceTokenRepository;

    private volatile boolean ready;

    @PostConstruct
    void init() {
        HrmProperties.Push push = properties.getPush();
        if (!push.isEnabled()) {
            log.info("FCM push disabled (minhan.hrm.push.enabled=false)");
            return;
        }
        String credentialsPath = push.getCredentialsPath();
        if (credentialsPath == null || credentialsPath.isBlank()) {
            log.warn("FCM push enabled nhưng chưa cấu hình credentials-path — bỏ qua khởi tạo");
            return;
        }
        Path path = Path.of(credentialsPath);
        if (!Files.isRegularFile(path)) {
            log.warn("FCM credentials không tồn tại: {}", path.toAbsolutePath());
            return;
        }
        try (InputStream in = new FileInputStream(path.toFile())) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(in))
                    .build();
            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
            }
            ready = true;
            log.info("FCM push đã sẵn sàng");
        } catch (Exception e) {
            log.error("Không khởi tạo được Firebase Admin SDK", e);
        }
    }

    public boolean isReady() {
        return ready;
    }

    @Async
    public void sendAsync(Long userId, NotificationDto dto) {
        if (!ready || userId == null || dto == null) {
            return;
        }
        List<UserDeviceToken> tokens = deviceTokenRepository.findByUserId(userId);
        if (tokens.isEmpty()) {
            return;
        }
        Map<String, String> data = new HashMap<>();
        data.put("notificationId", String.valueOf(dto.getId()));
        data.put("category", dto.getCategory() != null ? dto.getCategory().name() : "");
        data.put("actionPath", dto.getActionPath() != null ? dto.getActionPath() : "");
        if (dto.getRelatedRequestId() != null) {
            data.put("relatedRequestId", String.valueOf(dto.getRelatedRequestId()));
        }
        data.put("title", dto.getTitle() != null ? dto.getTitle() : "");
        data.put("body", dto.getMessage() != null ? dto.getMessage() : "");

        for (UserDeviceToken row : tokens) {
            try {
                Message message = Message.builder()
                        .setToken(row.getToken())
                        .setNotification(Notification.builder()
                                .setTitle(dto.getTitle())
                                .setBody(dto.getMessage())
                                .build())
                        .putAllData(data)
                        .build();
                FirebaseMessaging.getInstance().send(message);
            } catch (FirebaseMessagingException e) {
                log.warn("Gửi FCM thất bại tokenId={}: {}", row.getId(), e.getMessagingErrorCode());
                if (isInvalidToken(e)) {
                    deviceTokenRepository.delete(row);
                }
            } catch (Exception e) {
                log.warn("Gửi FCM lỗi không xác định tokenId={}: {}", row.getId(), e.getMessage());
            }
        }
    }

    private static boolean isInvalidToken(FirebaseMessagingException e) {
        if (e.getMessagingErrorCode() == null) {
            return false;
        }
        return switch (e.getMessagingErrorCode().name()) {
            case "UNREGISTERED", "INVALID_ARGUMENT" -> true;
            default -> false;
        };
    }
}
