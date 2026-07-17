package com.minhan.hrm.controller;

import com.minhan.hrm.dto.sso.AccountGrantRequest;
import com.minhan.hrm.dto.sso.AccountGrantResponse;
import com.minhan.hrm.dto.sso.EmployeeAccountCandidatePageDto;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.sso.SsoEmployeeAccountService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.Set;

/**
 * Cấp tài khoản đăng nhập HRM — path khớp tài liệu mobile để API Gateway chuyển tiếp trực tiếp
 * (POST /j1-api/hrm/employees/{UserEnrollNumber}/account, GET /j1-api/hrm/employees?hasAccount=false).
 * Dùng chung JWT nội bộ HRM hiện có; quyền tương đương "admin/Manager" của tài liệu là
 * ADMIN / HR / DIRECTOR trong hệ thống vai trò HRM.
 */
@RestController
@RequestMapping("/j1-api/hrm/employees")
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "HRM — Cấp tài khoản đăng nhập", description = "API mobile cấp tài khoản đăng nhập cho nhân viên chưa có tài khoản")
public class HrmEmployeeAccountController {

    private static final Set<String> ALLOWED_AUTHORITIES = Set.of("ROLE_ADMIN", "ROLE_HR", "ROLE_DIRECTOR");

    private final SsoEmployeeAccountService ssoEmployeeAccountService;

    @GetMapping
    @Operation(summary = "Danh sách nhân viên chưa có tài khoản (hasAccount=false), lọc theo search/dept, phân trang")
    public EmployeeAccountCandidatePageDto list(
            @RequestParam(required = false, defaultValue = "false") boolean hasAccount,
            @RequestParam(required = false) String search,
            @RequestParam(required = false, defaultValue = "1") Integer page,
            @RequestParam(required = false, defaultValue = "100") Integer limit,
            @RequestParam(required = false) String dept) {
        assertAccountManagementAllowed();
        if (hasAccount) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ hỗ trợ hasAccount=false");
        }
        return ssoEmployeeAccountService.listEmployeesWithoutAccount(search, page, limit, dept);
    }

    @PostMapping("/{userEnrollNumber}/account")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cấp tài khoản đăng nhập HRM cho nhân viên theo UserEnrollNumber (mã chấm công)")
    public AccountGrantResponse grant(
            @PathVariable long userEnrollNumber,
            @RequestBody(required = false) AccountGrantRequest request) {
        assertAccountManagementAllowed();
        return ssoEmployeeAccountService.grantAccount(
                userEnrollNumber, request != null ? request : new AccountGrantRequest());
    }

    private void assertAccountManagementAllowed() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        boolean allowed = auth != null
                && auth.getAuthorities().stream()
                        .map(GrantedAuthority::getAuthority)
                        .anyMatch(ALLOWED_AUTHORITIES::contains);
        if (!allowed) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Bạn không có quyền thực hiện hành động này");
        }
    }
}
