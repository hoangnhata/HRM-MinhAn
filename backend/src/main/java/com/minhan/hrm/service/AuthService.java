package com.minhan.hrm.service;

import com.minhan.hrm.dto.auth.ErpLoginResponse;
import com.minhan.hrm.dto.auth.LoginRequest;
import com.minhan.hrm.dto.auth.LoginResponse;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.security.CustomUserDetailsService;
import com.minhan.hrm.security.JwtService;
import com.minhan.hrm.sso.ErpAuthClient;
import com.minhan.hrm.sso.SsoRoleService;
import com.minhan.hrm.sso.SsoUserRoleMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/**
 * Đăng nhập qua ERP API + phân quyền từ sso_db (192.168.8.16).
 * Không xác thực mật khẩu trên MySQL.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final ErpAuthClient erpAuthClient;
    private final ObjectProvider<SsoRoleService> ssoRoleService;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeRepository employeeRepository;
    private final CustomUserDetailsService userDetailsService;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public LoginResponse login(LoginRequest request) {
        String username = request.getUsername() != null ? request.getUsername().trim() : "";
        if (username.isBlank() || request.getPassword() == null || request.getPassword().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Nhập số điện thoại và mật khẩu");
        }

        String as84 = toErpLoginPhone(username);
        String asLocal = digitsOnly(username);
        ErpLoginResponse erp = loginErpWithFallbacks(as84, asLocal, username, request.getPassword());
        String phoneKey = as84;

        UserRole role = resolveHrmRoleFromSso(phoneKey);
        UserAccount user = upsertLocalAccount(phoneKey, role, erp);

        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getUsername());
        String token = jwtService.generateToken(userDetails, user.getId(), user.getRole().name());

        Long employeeId = null;
        String fullName = erp.getUser() != null && erp.getUser().getName() != null
                ? erp.getUser().getName()
                : user.getUsername();
        var empOpt = employeeRepository.findByUser(user);
        if (empOpt.isPresent()) {
            Employee e = empOpt.get();
            employeeId = e.getId();
            fullName = e.getFullName();
        }

        return LoginResponse.builder()
                .accessToken(token)
                .tokenType("Bearer")
                .role(user.getRole())
                .userId(user.getId())
                .employeeId(employeeId)
                .fullName(fullName)
                .email(user.getEmail())
                .mustChangePassword(false)
                .build();
    }

    private ErpLoginResponse loginErpWithFallbacks(String as84, String asLocal, String raw, String password) {
        ApiException last401 = null;
        for (String candidate : List.of(as84, asLocal, raw)) {
            if (candidate == null || candidate.isBlank()) {
                continue;
            }
            try {
                return erpAuthClient.login(candidate, password);
            } catch (ApiException ex) {
                if (ex.getStatus() == HttpStatus.UNAUTHORIZED) {
                    last401 = ex;
                    continue;
                }
                throw ex;
            }
        }
        throw last401 != null ? last401 : new ApiException(HttpStatus.UNAUTHORIZED, "Sai số điện thoại hoặc mật khẩu");
    }

    private UserRole resolveHrmRoleFromSso(String loginPhone) {
        SsoRoleService sso = ssoRoleService.getIfAvailable();
        if (sso == null) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "SSO chưa kết nối (sso_db) — không lấy được phân quyền HRM");
        }
        return sso.findHrmRoleByLoginPhone(loginPhone)
                .map(dto -> SsoUserRoleMapper.toUserRole(dto.getRoleCode()))
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN,
                        "Tài khoản chưa được gán vai trò HRM trên SSO. Liên hệ quản trị để gán role."));
    }

    private UserAccount upsertLocalAccount(String loginPhone, UserRole role, ErpLoginResponse erp) {
        Optional<UserAccount> existing = findLocalUser(loginPhone);
        if (existing.isPresent()) {
            UserAccount user = existing.get();
            user.setRole(role);
            user.setEnabled(true);
            user.setMustChangePassword(false);
            if (erp.getToken() != null && !erp.getToken().isBlank()) {
                user.setErpAccessToken(erp.getToken().trim());
            }
            if (erp.getUser() != null && erp.getUser().getName() != null && !erp.getUser().getName().isBlank()) {
                user.setDisplayName(erp.getUser().getName().trim());
            }
            return userAccountRepository.save(user);
        }

        String email = digitsOnly(loginPhone) + "@erp.minhan.local";
        String erpName = erp.getUser() != null && erp.getUser().getName() != null
                ? erp.getUser().getName().trim()
                : null;
        UserAccount created = UserAccount.builder()
                .username(loginPhone.trim())
                .passwordHash(passwordEncoder.encode(UUID.randomUUID().toString()))
                .email(email)
                .displayName(erpName != null && !erpName.isBlank() ? erpName : null)
                .erpAccessToken(erp.getToken() != null ? erp.getToken().trim() : null)
                .role(role)
                .enabled(true)
                .mustChangePassword(false)
                .build();
        return userAccountRepository.save(created);
    }

    private Optional<UserAccount> findLocalUser(String loginPhone) {
        for (String candidate : usernameCandidates(loginPhone)) {
            Optional<UserAccount> found = userAccountRepository.findByUsername(candidate);
            if (found.isPresent()) {
                return found;
            }
        }
        return Optional.empty();
    }

    private static Set<String> usernameCandidates(String phone) {
        Set<String> out = new LinkedHashSet<>();
        if (phone == null || phone.isBlank()) {
            return out;
        }
        out.add(phone.trim());
        String digits = digitsOnly(phone);
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

    /** Chuẩn hóa SĐT kiểu VN cho ERP/SSO: 036… → 8436… */
    static String toErpLoginPhone(String raw) {
        String digits = digitsOnly(raw);
        if (digits.startsWith("0") && digits.length() >= 10) {
            return "84" + digits.substring(1);
        }
        return digits.isEmpty() ? raw.trim() : digits;
    }
}
