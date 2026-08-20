package com.minhan.hrm.service;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class SalaryAccessService {

    private final HrmProperties properties;
    private final EmployeeService employeeService;
    private final SecureRandom secureRandom = new SecureRandom();
    private final Map<String, Grant> grants = new ConcurrentHashMap<>();

    public UnlockResult unlock(String password) {
        UserRole role = employeeService.currentUser().getRole();
        if (role != UserRole.ADMIN && role != UserRole.HR) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ ADMIN/HCNS 1 được mở khóa bảng lương");
        }
        String expected = properties.getSalaryAccess().getPassword();
        if (password == null || expected == null || !MessageDigest.isEqual(
                password.getBytes(StandardCharsets.UTF_8),
                expected.getBytes(StandardCharsets.UTF_8))) {
            // Đây là lỗi mật khẩu của khu vực lương, không phải lỗi phiên đăng nhập.
            throw new ApiException(HttpStatus.BAD_REQUEST, "Sai mật khẩu, vui lòng nhập lại");
        }

        cleanupExpired();
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        Instant expiresAt = Instant.now().plusMillis(properties.getSalaryAccess().getExpirationMs());
        grants.put(token, new Grant(SecurityUtils.currentUsername(), expiresAt));
        return new UnlockResult(token, expiresAt);
    }

    public void requireAdminGrant(String token) {
        UserRole role = employeeService.currentUser().getRole();
        if (role != UserRole.ADMIN && role != UserRole.HR) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ ADMIN/HCNS 1 có quyền quản lý lương");
        }
        Grant grant = token == null ? null : grants.get(token);
        String username = SecurityUtils.currentUsername();
        if (grant == null || grant.expiresAt().isBefore(Instant.now())
                || username == null || !username.equals(grant.username())) {
            if (token != null) grants.remove(token);
            throw new ApiException(HttpStatus.FORBIDDEN, "Vui lòng nhập mật khẩu để mở khóa phần lương");
        }
    }

    public boolean hasAdminGrant(String token) {
        try {
            requireAdminGrant(token);
            return true;
        } catch (ApiException ex) {
            return false;
        }
    }

    private void cleanupExpired() {
        Instant now = Instant.now();
        grants.entrySet().removeIf(e -> e.getValue().expiresAt().isBefore(now));
    }

    private record Grant(String username, Instant expiresAt) {}
    public record UnlockResult(String token, Instant expiresAt) {}
}
