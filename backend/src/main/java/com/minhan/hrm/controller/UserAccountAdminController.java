package com.minhan.hrm.controller;

import com.minhan.hrm.dto.account.EmployeeWithoutAccountDto;
import com.minhan.hrm.dto.account.LocalAccountGrantRequest;
import com.minhan.hrm.dto.account.UserAccountAdminDto;
import com.minhan.hrm.dto.account.UserAccountIdentifiersUpdateRequest;
import com.minhan.hrm.dto.account.UserAccountRoleUpdateRequest;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.service.UserAccountAdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/admin/user-accounts")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Admin — Tài khoản đăng nhập", description = "Quản lý tài khoản local (độc lập SSO)")
public class UserAccountAdminController {

    private final UserAccountAdminService userAccountAdminService;

    @GetMapping
    @Operation(summary = "Danh sách tài khoản đăng nhập local")
    public Page<UserAccountAdminDto> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) String workUnitDetail,
            @RequestParam(required = false) UserRole role,
            @RequestParam(required = false) Boolean inactiveOnly,
            @PageableDefault(size = 25, sort = "username", direction = Sort.Direction.ASC) Pageable pageable) {
        return userAccountAdminService.list(q, departmentId, workUnitDetail, role, inactiveOnly, pageable);
    }

    @GetMapping("/without-account")
    @Operation(summary = "Nhân sự chưa có tài khoản (thiếu user hoặc thiếu SĐT)")
    public Page<EmployeeWithoutAccountDto> listWithoutAccount(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) String workUnitDetail,
            @PageableDefault(size = 25) Pageable pageable) {
        return userAccountAdminService.listWithoutAccount(q, departmentId, workUnitDetail, pageable);
    }

    @PutMapping("/{userId}/role")
    @Operation(summary = "Đổi vai trò HRM theo tài khoản")
    public UserAccountAdminDto updateRole(
            @PathVariable Long userId, @Valid @RequestBody UserAccountRoleUpdateRequest request) {
        return userAccountAdminService.updateRole(userId, request);
    }

    @PutMapping("/{userId}/identifiers")
    @Operation(summary = "Đổi SĐT đăng nhập và mã chấm công của nhân viên")
    public UserAccountAdminDto updateIdentifiers(
            @PathVariable Long userId,
            @Valid @RequestBody UserAccountIdentifiersUpdateRequest request) {
        return userAccountAdminService.updateIdentifiers(userId, request);
    }

    @PutMapping("/{userId}/enabled")
    @Operation(summary = "Khóa / mở tài khoản")
    public UserAccountAdminDto setEnabled(@PathVariable Long userId, @RequestBody Map<String, Boolean> body) {
        Boolean enabled = body != null ? body.get("enabled") : null;
        if (enabled == null) {
            throw new com.minhan.hrm.exception.ApiException(HttpStatus.BAD_REQUEST, "Thiếu enabled");
        }
        return userAccountAdminService.setEnabled(userId, enabled);
    }

    @PutMapping("/{userId}/director-approval")
    @Operation(summary = "Bật / tắt quyền duyệt đơn cấp Giám đốc")
    public UserAccountAdminDto setDirectorApproval(
            @PathVariable Long userId, @RequestBody Map<String, Boolean> body) {
        Boolean enabled = body != null ? body.get("enabled") : null;
        if (enabled == null) {
            throw new com.minhan.hrm.exception.ApiException(HttpStatus.BAD_REQUEST, "Thiếu enabled");
        }
        return userAccountAdminService.setDirectorApprovalEnabled(userId, enabled);
    }

    @PutMapping("/{userId}/report-view")
    @Operation(summary = "Bật / tắt quyền xem báo cáo nhân lực")
    public UserAccountAdminDto setReportView(
            @PathVariable Long userId, @RequestBody Map<String, Boolean> body) {
        Boolean enabled = body != null ? body.get("enabled") : null;
        if (enabled == null) {
            throw new com.minhan.hrm.exception.ApiException(HttpStatus.BAD_REQUEST, "Thiếu enabled");
        }
        return userAccountAdminService.setReportViewEnabled(userId, enabled);
    }

    @PutMapping("/{userId}/work-unit-scope")
    @Operation(summary = "Bật / tắt Trưởng bộ phận (chỉ quản lý bộ phận, không cả khoa)")
    public UserAccountAdminDto setWorkUnitScope(
            @PathVariable Long userId, @RequestBody Map<String, Boolean> body) {
        Boolean enabled = body != null ? body.get("enabled") : null;
        if (enabled == null) {
            throw new com.minhan.hrm.exception.ApiException(HttpStatus.BAD_REQUEST, "Thiếu enabled");
        }
        return userAccountAdminService.setWorkUnitScoped(userId, enabled);
    }

    @PostMapping("/{userId}/reset-password")
    @Operation(summary = "Reset mật khẩu về mặc định + bắt đổi lần đầu")
    public UserAccountAdminDto resetPassword(@PathVariable Long userId) {
        return userAccountAdminService.resetPassword(userId);
    }

    @PostMapping("/grant")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cấp tài khoản: gán SĐT + mã chấm công + tạo user đăng nhập")
    public UserAccountAdminDto grant(@Valid @RequestBody LocalAccountGrantRequest request) {
        return userAccountAdminService.grant(request);
    }
}
