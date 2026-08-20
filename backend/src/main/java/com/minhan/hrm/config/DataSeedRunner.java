package com.minhan.hrm.config;

import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Chỉ seed tài khoản quản trị trong môi trường không phải production.
 * Mọi vai trò nghiệp vụ được ADMIN phân thủ công.
 */
@Slf4j
@Component
@Order(Integer.MAX_VALUE - 1)
@RequiredArgsConstructor
@Profile("!prod")
public class DataSeedRunner implements ApplicationRunner {

    private final UserAccountRepository userAccountRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        boolean createdAny = false;
        createdAny |= ensureAccount("admin", "Admin@123", "admin@minhan.vn", UserRole.ADMIN);

        if (createdAny) {
            log.info("Data seed account ready: admin");
        } else {
            log.info("Skip data seed — system accounts already exist");
        }
    }

    /** @return true nếu vừa tạo mới */
    private boolean ensureAccount(String username, String rawPassword, String email, UserRole role) {
        if (userAccountRepository.findByUsername(username).isPresent()) {
            return false;
        }
        userAccountRepository.save(UserAccount.builder()
                .username(username)
                .passwordHash(passwordEncoder.encode(rawPassword))
                .email(email)
                .role(role)
                .directorApprovalEnabled(role == UserRole.ADMIN || "giamdoc".equals(username))
                .enabled(true)
                .mustChangePassword(true)
                .build());
        return true;
    }
}
