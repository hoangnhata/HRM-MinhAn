package com.minhan.hrm.controller;

import com.minhan.hrm.dto.sso.SsoHrmRoleDto;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.sso.SsoRoleService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * API public — trả roleCode HRM theo LoginPhone (không cần JWT).
 * Dùng cho tích hợp SSO / app khác đọc quyền HRM.
 */
@RestController
@RequestMapping("/j1-api/v1/sso/public")
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
@Tag(name = "SSO public", description = "Tra cứu role HRM trên sso_db (public)")
public class SsoPublicController {

    private final SsoRoleService ssoRoleService;

    @GetMapping("/hrm-role")
    @Operation(summary = "Lấy RoleCode HRM theo LoginPhone")
    public Map<String, Object> hrmRoleByPhone(@RequestParam String loginPhone) {
        if (loginPhone == null || loginPhone.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu loginPhone");
        }
        SsoHrmRoleDto role = ssoRoleService.findHrmRoleByLoginPhone(loginPhone)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Không có role HRM cho SĐT này (hoặc chưa gán UserAppRoles)"));

        Map<String, Object> apps = new LinkedHashMap<>();
        Map<String, Object> hrm = new LinkedHashMap<>();
        hrm.put("roleCode", role.getRoleCode());
        hrm.put("roleName", role.getRoleName());
        apps.put(role.getAppCode(), hrm);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("accountId", role.getAccountId());
        body.put("loginPhone", role.getLoginPhone());
        body.put("userEnrollNumber", role.getUserEnrollNumber());
        body.put("apps", apps);
        return body;
    }
}
