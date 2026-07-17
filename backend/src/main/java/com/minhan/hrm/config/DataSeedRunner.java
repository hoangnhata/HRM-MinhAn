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
 * Seed 5 tài khoản hệ thống khi DB trống / thiếu admin (profile khác prod).
 * Nhân viên còn lại tạo qua import Excel — role theo khoa/chức vụ.
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
        createdAny |= ensureAccount("hcns", "Hcns@123", "hcns@minhan.vn", UserRole.HR);
        createdAny |= ensureAccount("truongkhoa", "Tk@12345", "truongkhoa@minhan.vn", UserRole.HEAD_DEPARTMENT);
        createdAny |= ensureAccount("dieuduongtruong", "Ddt@12345", "ddt@minhan.vn", UserRole.HEAD_NURSING);
        createdAny |= ensureAccount("giamdoc", "Giamdoc@123", "giamdoc@minhan.vn", UserRole.DIRECTOR);

        if (createdAny) {
            log.info("Data seed accounts ready: admin / hcns / truongkhoa / dieuduongtruong / giamdoc");
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
                .enabled(true)
                .mustChangePassword(false)
                .build());
        return true;
    }
}
