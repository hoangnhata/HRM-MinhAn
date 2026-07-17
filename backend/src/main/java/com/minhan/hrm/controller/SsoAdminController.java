package com.minhan.hrm.controller;

import com.minhan.hrm.dto.sso.SsoAccountAdminRowDto;
import com.minhan.hrm.dto.sso.SsoAssignHrmRoleRequest;
import com.minhan.hrm.dto.sso.SsoHrmRoleDto;
import com.minhan.hrm.dto.sso.SsoRoleCatalogDto;
import com.minhan.hrm.dto.sso.SsoSyncResultDto;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.sso.SsoAccountAdminService;
import com.minhan.hrm.sso.SsoRoleService;
import com.minhan.hrm.sso.SsoRoleSyncService;
import com.minhan.hrm.sso.SsoUserRoleMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/sso")
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "SSO admin", description = "Quản lý Roles / UserAppRoles trên sso_db")
public class SsoAdminController {

    private final SsoRoleService ssoRoleService;
    private final SsoRoleSyncService ssoRoleSyncService;
    private final SsoAccountAdminService ssoAccountAdminService;

    @GetMapping("/hrm-roles")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Danh mục 6 role HRM trên SSO")
    public List<SsoRoleCatalogDto> listRoles() {
        return ssoRoleService.listHrmRoles();
    }

    @GetMapping("/accounts")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Danh sách tài khoản SSO + role HRM (lọc tên/SĐT/mã chấm công, phòng ban)")
    public List<SsoAccountAdminRowDto> listAccounts(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Long departmentId) {
        return ssoAccountAdminService.listAccounts(q, departmentId);
    }

    @PostMapping("/schema/ensure")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Tạo bảng Roles/UserAppRoles + seed 6 role + cột roleId_ts (idempotent)")
    public Map<String, Object> ensureSchema() {
        ssoRoleService.ensureSchemaAndSeedRoles();
        ssoRoleService.ensureAccountProvisioningColumns();
        return Map.of("ok", true, "roles", ssoRoleService.listHrmRoles().size());
    }

    @PostMapping("/assign-defaults")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Gán ADMIN/EMPLOYEE từ cột legacy roles cho account chưa có")
    public Map<String, Object> assignDefaults() {
        int assigned = ssoRoleService.assignDefaultsFromLegacyRoles();
        return Map.of("ok", true, "assigned", assigned);
    }

    @PutMapping("/accounts/{accountId}/hrm-role")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Gán / đổi role HRM cho AccountId SSO (đồng bộ HRM nếu có)")
    public SsoHrmRoleDto assign(
            @PathVariable long accountId,
            @Valid @RequestBody SsoAssignHrmRoleRequest body) {
        return ssoAccountAdminService.assignAndSync(accountId, body.getRoleCode());
    }

    @PostMapping("/sync-hrm-user")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Đồng bộ RoleCode SSO → users.role trong HRM theo SĐT")
    public SsoSyncResultDto syncHrmUser(@RequestParam String loginPhone) {
        return ssoRoleSyncService.syncHrmRoleByLoginPhone(loginPhone);
    }

    @GetMapping("/map-role")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Map RoleCode SSO → UserRole HRM")
    public Map<String, Object> mapRole(@RequestParam String roleCode) {
        UserRole role = SsoUserRoleMapper.toUserRole(roleCode);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("roleCode", roleCode.trim().toUpperCase());
        m.put("userRole", role.name());
        return m;
    }
}
