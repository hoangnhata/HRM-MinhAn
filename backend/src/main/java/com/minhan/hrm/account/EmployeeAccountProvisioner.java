package com.minhan.hrm.account;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.Position;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.text.Normalizer;
import java.util.Locale;

/**
 * Tạo tài khoản nhân viên: username = SĐT (chuẩn hóa), mật khẩu mặc định, bắt đổi MK lần đầu.
 * Role suy ra từ khoa/phòng + chức vụ khi import.
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
        return buildNewEmployeeUser(phone, fallbackCode, email, UserRole.EMPLOYEE);
    }

    public UserAccount buildNewEmployeeUser(String phone, String fallbackCode, String email, UserRole role) {
        return UserAccount.builder()
                .username(resolveUniqueUsername(phone, fallbackCode))
                .passwordHash(passwordEncoder.encode(hrmProperties.getImportConfig().getDefaultEmployeePassword()))
                .email(email)
                .role(role != null ? role : UserRole.EMPLOYEE)
                .enabled(true)
                .mustChangePassword(true)
                .build();
    }

    /**
     * Import nhân sự không tự phân quyền. Vai trò HCNS, trưởng khoa/phòng,
     * điều dưỡng trưởng và giám đốc chỉ được gán thủ công sau khi có tài khoản.
     */
    public void applyImportRole(UserAccount user, Department department, Position position) {
        // Cố ý không làm gì để không ghi đè vai trò do ADMIN đã phân.
    }

    public UserRole resolveImportRole(Department department, Position position) {
        // Tài khoản mới luôn bắt đầu là nhân viên; ADMIN sẽ phân quyền khi cần.
        return UserRole.EMPLOYEE;
    }

    private static boolean matchesDirector(String folded) {
        if (folded == null || folded.isBlank()) {
            return false;
        }
        // "pho giam doc" không map DIRECTOR
        if (folded.contains("pho giam doc")) {
            return false;
        }
        return folded.contains("giam doc") || folded.equals("gd");
    }

    public static boolean isNursingHead(UserAccount user) {
        if (user == null) {
            return false;
        }
        if (user.getEmployee() != null && user.getEmployee().getPosition() != null
                && isNursingHeadTitle(fold(user.getEmployee().getPosition().getTitle()))) {
            return true;
        }
        // Tài khoản seed không gắn hồ sơ nhân viên.
        return "dieuduongtruong".equalsIgnoreCase(user.getUsername());
    }

    public static boolean isNursingHeadTitle(String title) {
        String normalized = fold(title);
        return normalized.contains("dieu duong") || normalized.contains("ddt");
    }

    private static String fold(String s) {
        if (s == null) {
            return "";
        }
        String n = Normalizer.normalize(s, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.ROOT)
                .replace('đ', 'd')
                .replaceAll("[^a-z0-9]+", " ")
                .trim()
                .replaceAll("\\s+", " ");
        return n;
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
