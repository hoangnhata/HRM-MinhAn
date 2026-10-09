package com.minhan.hrm.service;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRefreshToken;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.UserRefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;

/**
 * Refresh token cho app di động: giữ người dùng đăng nhập tới khi họ tự đăng xuất.
 *
 * <p>Token gốc là 32 byte ngẫu nhiên (base64url), chỉ trả cho thiết bị một lần; DB lưu
 * SHA-256. Hạn trượt: mỗi lần dùng được kéo dài thêm {@code refresh-expiration-ms}, nên
 * người dùng mở app ít nhất một lần trong khoảng đó sẽ không bao giờ phải đăng nhập lại.
 * Token không xoay vòng sau mỗi lần dùng — tránh việc mạng chập chờn làm mất token mới
 * vừa cấp và văng thiết bị ra ngoài.
 */
@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private static final SecureRandom RANDOM = new SecureRandom();
    /** Giữ bản ghi đã hết hạn / thu hồi thêm 30 ngày để tra cứu trước khi dọn. */
    private static final Duration STALE_RETENTION = Duration.ofDays(30);

    private final UserRefreshTokenRepository repository;
    private final HrmProperties hrmProperties;

    /** Cấp refresh token mới cho thiết bị vừa đăng nhập; trả token gốc. */
    @Transactional
    public String issue(UserAccount user, String deviceLabel) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String raw = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        Instant now = Instant.now();
        repository.save(UserRefreshToken.builder()
                .user(user)
                .tokenHash(hash(raw))
                .deviceLabel(trimLabel(deviceLabel))
                .createdAt(now)
                .lastUsedAt(now)
                .expiresAt(now.plusMillis(lifetimeMs()))
                .build());
        return raw;
    }

    /**
     * Xác thực refresh token, kéo dài hạn dùng và trả tài khoản sở hữu.
     * Token sai / hết hạn / đã thu hồi / tài khoản bị khoá → 401 để app đăng xuất.
     */
    @Transactional
    public UserAccount use(String raw) {
        if (raw == null || raw.isBlank()) {
            throw invalid();
        }
        UserRefreshToken token = repository.findByTokenHash(hash(raw.trim()))
                .orElseThrow(RefreshTokenService::invalid);
        Instant now = Instant.now();
        if (!token.isActive(now)) {
            throw invalid();
        }
        UserAccount user = token.getUser();
        if (user == null || !user.isEnabled()) {
            token.setRevokedAt(now);
            throw invalid();
        }
        token.setLastUsedAt(now);
        token.setExpiresAt(now.plusMillis(lifetimeMs()));
        return user;
    }

    /** Thu hồi token của thiết bị đang đăng xuất. Token không tồn tại thì bỏ qua. */
    @Transactional
    public void revoke(String raw) {
        if (raw == null || raw.isBlank()) {
            return;
        }
        repository.findByTokenHash(hash(raw.trim())).ifPresent(t -> {
            if (t.getRevokedAt() == null) {
                t.setRevokedAt(Instant.now());
            }
        });
    }

    /** Thu hồi mọi thiết bị của tài khoản (admin reset mật khẩu, khoá tài khoản). */
    @Transactional
    public void revokeAll(Long userId) {
        if (userId != null) {
            repository.revokeAllForUser(userId, Instant.now());
        }
    }

    /** Dọn bản ghi đã hết hạn / thu hồi quá 30 ngày, chạy mỗi ngày lúc 3:30. */
    @Scheduled(cron = "0 30 3 * * *")
    @Transactional
    public void purgeStale() {
        repository.deleteStale(Instant.now().minus(STALE_RETENTION));
    }

    private long lifetimeMs() {
        return hrmProperties.getJwt().getRefreshExpirationMs();
    }

    private static String trimLabel(String label) {
        if (label == null || label.isBlank()) {
            return null;
        }
        String t = label.trim();
        return t.length() > 120 ? t.substring(0, 120) : t;
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.");
    }

    static String hash(String raw) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(raw.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 không khả dụng", e);
        }
    }
}
