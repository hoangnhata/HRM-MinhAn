package com.minhan.hrm.account;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.Locale;

/**
 * Tạo tài khoản nhân viên: username = SĐT (chuẩn hóa), mật khẩu mặc định, bắt đổi MK lần đầu.
 */
@Component
@RequiredArgsConstructor
public class EmployeeAccountProvisioner {

    private final UserAccountRepository userAccountRepository;
    private final PasswordEncoder passwordEncoder;
    private final HrmProperties hrmProperties;

    public String normalizePhoneUsername(String phone) {
        if (phone == null) {
            return null;
        }
        String digits = phone.replaceAll("\\D", "");
        if (digits.isEmpty()) {
            return null;
        }
        if (digits.startsWith("84") && digits.length() >= 11) {
            digits = "0" + digits.substring(2);
        }
        return digits;
    }

    public String resolveUniqueUsername(String phone, String fallbackCode) {
        String base = normalizePhoneUsername(phone);
        if (base == null || base.isBlank()) {
            base = sanitizeUsername(fallbackCode);
        }
        if (base == null || base.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần số điện thoại hoặc mã nhân viên để tạo tài khoản");
        }
        return uniqueUsername(base);
    }

    public UserAccount buildNewEmployeeUser(String phone, String fallbackCode, String email) {
        return UserAccount.builder()
                .username(resolveUniqueUsername(phone, fallbackCode))
                .passwordHash(passwordEncoder.encode(hrmProperties.getImportConfig().getDefaultEmployeePassword()))
                .email(email)
                .role(UserRole.EMPLOYEE)
                .enabled(true)
                .mustChangePassword(true)
                .build();
    }

    private String uniqueUsername(String base) {
        String u = base;
        int i = 0;
        while (userAccountRepository.existsByUsername(u)) {
            u = base + (++i);
        }
        return u;
    }

    public static String sanitizeUsername(String code) {
        if (code == null) {
            return null;
        }
        String s = code.replaceAll("[^a-zA-Z0-9]", "");
        if (s.isEmpty()) {
            s = "nv" + Math.abs(code.hashCode() % 1_000_000);
        }
        if (s.length() > 50) {
            s = s.substring(0, 50);
        }
        return s.toLowerCase(Locale.ROOT);
    }
}
