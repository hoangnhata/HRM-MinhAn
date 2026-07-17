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
     * Gán role theo khoa/chức vụ khi import. Không đổi role ADMIN hoặc các tài khoản hệ thống.
     */
    public void applyImportRole(UserAccount user, Department department, Position position) {
        if (user == null || user.getRole() == UserRole.ADMIN) {
            return;
        }
        String u = user.getUsername() != null ? user.getUsername().toLowerCase(Locale.ROOT) : "";
        if (u.equals("admin") || u.equals("giamdoc") || u.equals("hcns")
                || u.equals("truongkhoa") || u.equals("dieuduongtruong")) {
            return;
        }
        user.setRole(resolveImportRole(department, position));
    }

    public UserRole resolveImportRole(Department department, Position position) {
        String dept = fold(department != null ? department.getName() : null);
        String deptCode = department != null && department.getCode() != null
                ? department.getCode().trim().toUpperCase(Locale.ROOT) : "";
        String title = fold(position != null ? position.getTitle() : null);

        // Chức vụ ưu tiên trước khoa
        if (matchesDirector(title) || matchesDirector(dept)) {
            return UserRole.DIRECTOR;
        }
        if (title.contains("dieu duong truong") || title.contains("ddt")) {
            return UserRole.HEAD_NURSING;
        }
        if (title.contains("truong khoa")
                || title.contains("truong phong")
                || title.contains("truong bo phan")
                || title.contains("truong don vi")) {
            return UserRole.HEAD_DEPARTMENT;
        }
        if ("HCNS".equals(deptCode)
                || dept.contains("hanh chinh") && (dept.contains("nhan su") || dept.contains("hcns"))
                || dept.contains("phong hcns")
                || dept.equals("hcns")) {
            return UserRole.HR;
        }
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
