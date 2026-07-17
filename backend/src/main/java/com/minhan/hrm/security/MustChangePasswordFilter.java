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
 * Chặn mọi API (trừ đổi mật khẩu / xem hồ sơ) khi tài khoản bắt buộc đổi MK lần đầu.
 */
@Component
@RequiredArgsConstructor
public class MustChangePasswordFilter extends OncePerRequestFilter {

    private static final Set<String> ALLOWED_PATHS = Set.of(
            "/j1-api/v1/account/me",
            "/j1-api/v1/account/me/avatar",
            "/j1-api/v1/account/change-password");

    private final UserAccountRepository userAccountRepository;

    @Override
    protected void doFilterInternal(
            HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && auth.getName() != null) {
            UserAccount user = userAccountRepository.findByUsername(auth.getName()).orElse(null);
            if (user != null && user.isMustChangePassword()) {
                String path = request.getRequestURI();
                if (!ALLOWED_PATHS.contains(path)) {
                    response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                    response.setContentType("application/json;charset=UTF-8");
                    response.getWriter().write(
                            "{\"message\":\"Bạn cần đổi mật khẩu trước khi tiếp tục\",\"code\":\"MUST_CHANGE_PASSWORD\"}");
                    return;
                }
            }
        }
        filterChain.doFilter(request, response);
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
