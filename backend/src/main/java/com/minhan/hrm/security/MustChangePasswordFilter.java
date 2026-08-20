package com.minhan.hrm.security;

import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.repository.UserAccountRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpMethod;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Set;

/**
 * Lần đăng nhập đầu: bắt buộc đổi mật khẩu, rồi tạo chữ ký số trước khi dùng hệ thống.
 */
@Component
@RequiredArgsConstructor
public class MustChangePasswordFilter extends OncePerRequestFilter {

    private static final Set<String> ALLOWED_WHILE_CHANGE_PASSWORD = Set.of(
            "/j1-api/v1/account/me",
            "/j1-api/v1/account/me/avatar",
            "/j1-api/v1/account/change-password");

    private static final Set<String> ALLOWED_WHILE_SET_SIGNATURE = Set.of(
            "/j1-api/v1/account/me",
            "/j1-api/v1/account/me/avatar",
            "/j1-api/v1/account/me/signature");

    private final UserAccountRepository userAccountRepository;

    @Override
    protected void doFilterInternal(
            HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && auth.getName() != null) {
            UserAccount user = userAccountRepository.findByUsername(auth.getName()).orElse(null);
            if (user != null) {
                String path = request.getRequestURI();
                if (user.isMustChangePassword()) {
                    if (!ALLOWED_WHILE_CHANGE_PASSWORD.contains(path)) {
                        writeForbidden(response, "Bạn cần đổi mật khẩu trước khi tiếp tục", "MUST_CHANGE_PASSWORD");
                        return;
                    }
                } else if (user.getSignaturePath() == null || user.getSignaturePath().isBlank()) {
                    if (!ALLOWED_WHILE_SET_SIGNATURE.contains(path)) {
                        writeForbidden(response, "Bạn cần tạo chữ ký số trước khi tiếp tục", "MUST_SET_SIGNATURE");
                        return;
                    }
                }
            }
        }
        filterChain.doFilter(request, response);
    }

    private static void writeForbidden(HttpServletResponse response, String message, String code)
            throws IOException {
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write(
                "{\"message\":\"" + message + "\",\"code\":\"" + code + "\"}");
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        if (HttpMethod.OPTIONS.matches(request.getMethod())) {
            return true;
        }
        String path = request.getRequestURI();
        return !path.startsWith("/j1-api/")
                || path.startsWith("/j1-api/auth/")
                || path.startsWith("/swagger-ui")
                || path.startsWith("/api-docs")
                || path.startsWith("/v3/api-docs")
                || path.startsWith("/actuator/");
    }
}
