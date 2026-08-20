package com.minhan.hrm.service;

import com.minhan.hrm.dto.auth.LoginRequest;
import com.minhan.hrm.dto.auth.LoginResponse;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.security.CustomUserDetailsService;
import com.minhan.hrm.security.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.Optional;
import java.util.Set;

/**
 * Đăng nhập độc lập trên MySQL {@code users}: mật khẩu + role lưu local.
 * Không phụ thuộc ERP/SSO để xác thực.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserAccountRepository userAccountRepository;
    private final EmployeeLinkService employeeLinkService;
    private final CustomUserDetailsService userDetailsService;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;

    @Transactional(readOnly = true)
    public LoginResponse login(LoginRequest request) {
        String username = request.getUsername() != null ? request.getUsername().trim() : "";
        if (username.isBlank() || request.getPassword() == null || request.getPassword().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Nhập tên đăng nhập (hoặc SĐT) và mật khẩu");
        }

        UserAccount user = findLocalUser(username)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "Sai tên đăng nhập hoặc mật khẩu"));
        if (!user.isEnabled()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Tài khoản đã bị khóa. Liên hệ quản trị viên.");
        }
        if (user.getPasswordHash() == null
                || !passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Sai tên đăng nhập hoặc mật khẩu");
        }

        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getUsername());
        String token = jwtService.generateToken(userDetails, user.getId(), user.getRole().name());

        Long employeeId = null;
        String fullName = user.getDisplayName() != null && !user.getDisplayName().isBlank()
                ? user.getDisplayName()
                : user.getUsername();
        var empOpt = employeeLinkService.findLinkedEmployee(user);
        if (empOpt.isPresent()) {
            Employee e = empOpt.get();
            employeeId = e.getId();
            fullName = e.getFullName();
        }

        boolean mustSetSignature = user.getSignaturePath() == null || user.getSignaturePath().isBlank();

        return LoginResponse.builder()
                .accessToken(token)
                .tokenType("Bearer")
                .role(user.getRole())
                .userId(user.getId())
                .employeeId(employeeId)
                .fullName(fullName)
                .email(user.getEmail())
                .mustChangePassword(user.isMustChangePassword())
                .mustSetSignature(mustSetSignature)
                .build();
    }

    private Optional<UserAccount> findLocalUser(String login) {
        for (String candidate : usernameCandidates(login)) {
            Optional<UserAccount> found = userAccountRepository.findByUsername(candidate);
            if (found.isPresent()) {
                return found;
            }
        }
        return Optional.empty();
    }

    private static Set<String> usernameCandidates(String raw) {
        Set<String> out = new LinkedHashSet<>();
        if (raw == null || raw.isBlank()) {
            return out;
        }
        String trimmed = raw.trim();
        out.add(trimmed);
        out.add(trimmed.toLowerCase());
        String digits = digitsOnly(raw);
        if (!digits.isEmpty()) {
            out.add(digits);
            if (digits.startsWith("84") && digits.length() >= 11) {
                out.add("0" + digits.substring(2));
            }
            if (digits.startsWith("0") && digits.length() >= 10) {
                out.add("84" + digits.substring(1));
            }
        }
        return out;
    }

    private static String digitsOnly(String raw) {
        if (raw == null) {
            return "";
        }
        return raw.replaceAll("\\D", "");
    }
}
