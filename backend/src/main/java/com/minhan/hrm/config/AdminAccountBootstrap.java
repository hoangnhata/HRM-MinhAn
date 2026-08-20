package com.minhan.hrm.config;

import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Đảm bảo luôn có ít nhất một tài khoản ADMIN local để phân quyền.
 * Mật khẩu mặc định khi tạo mới: Admin@123 — lần đầu bắt đổi MK + tạo chữ ký.
 * <p>
 * Nếu đã có user {@code admin} từ thời ERP (mật khẩu random), đặt
 * {@code minhan.hrm.auth.reset-admin-password=true} một lần để đặt lại Admin@123.
 */
@Slf4j
@Component
@Order(Integer.MAX_VALUE - 2)
@RequiredArgsConstructor
public class AdminAccountBootstrap implements ApplicationRunner {

    public static final String ADMIN_USERNAME = "admin";
    public static final String ADMIN_DEFAULT_PASSWORD = "Admin@123";

    private final UserAccountRepository userAccountRepository;
    private final PasswordEncoder passwordEncoder;
    private final HrmProperties hrmProperties;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        boolean resetPw = hrmProperties.getAuth() != null && hrmProperties.getAuth().isResetAdminPassword();
        var existingOpt = userAccountRepository.findByUsername(ADMIN_USERNAME);

        if (existingOpt.isPresent()) {
            UserAccount existing = existingOpt.get();
            boolean changed = false;
            if (existing.getRole() != UserRole.ADMIN) {
                existing.setRole(UserRole.ADMIN);
                changed = true;
            }
            if (!existing.isEnabled()) {
                existing.setEnabled(true);
                changed = true;
            }
            if (resetPw) {
                existing.setPasswordHash(passwordEncoder.encode(ADMIN_DEFAULT_PASSWORD));
                existing.setMustChangePassword(true);
                changed = true;
                log.warn("Reset password for '{}' to default (minhan.hrm.auth.reset-admin-password=true)", ADMIN_USERNAME);
            }
            if (changed) {
                userAccountRepository.save(existing);
            }
            if (userAccountRepository.countByRole(UserRole.ADMIN) > 0) {
                log.info("Admin account ready: {}", ADMIN_USERNAME);
            }
            return;
        }

        if (userAccountRepository.countByRole(UserRole.ADMIN) > 0) {
            log.info("Admin role already assigned — skip creating '{}'", ADMIN_USERNAME);
            return;
        }

        userAccountRepository.save(UserAccount.builder()
                .username(ADMIN_USERNAME)
                .passwordHash(passwordEncoder.encode(ADMIN_DEFAULT_PASSWORD))
                .email("admin@minhan.vn")
                .displayName("Quản trị hệ thống")
                .role(UserRole.ADMIN)
                .enabled(true)
                .mustChangePassword(true)
                .build());
        log.info("Created local ADMIN '{}' (default password {}). Must change password + signature on first login.",
                ADMIN_USERNAME, ADMIN_DEFAULT_PASSWORD);
    }
}
