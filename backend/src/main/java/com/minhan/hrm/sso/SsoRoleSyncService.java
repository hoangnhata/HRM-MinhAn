package com.minhan.hrm.sso;

import com.minhan.hrm.dto.sso.SsoHrmRoleDto;
import com.minhan.hrm.dto.sso.SsoSyncResultDto;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.Optional;
import java.util.Set;

/**
 * Đồng bộ RoleCode SSO → users.role trong HRM (theo SĐT đăng nhập / username).
 */
@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
public class SsoRoleSyncService {

    private final SsoRoleService ssoRoleService;
    private final UserAccountRepository userAccountRepository;

    @Transactional
    public SsoSyncResultDto syncHrmRoleByLoginPhone(String loginPhone) {
        SsoHrmRoleDto sso = ssoRoleService.findHrmRoleByLoginPhone(loginPhone)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Không tìm thấy role HRM trên SSO cho SĐT: " + loginPhone));
        UserRole mapped = SsoUserRoleMapper.toUserRole(sso.getRoleCode());

        UserAccount user = findLocalUser(loginPhone, sso.getLoginPhone())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                        "Chưa có tài khoản HRM khớp SĐT SSO — tạo user HRM trước rồi sync lại"));

        boolean updated = user.getRole() != mapped;
        if (updated) {
            user.setRole(mapped);
            userAccountRepository.save(user);
        }
        return SsoSyncResultDto.builder()
                .loginPhone(sso.getLoginPhone())
                .ssoRoleCode(sso.getRoleCode())
                .hrmRole(mapped)
                .hrmUserId(user.getId())
                .hrmUsername(user.getUsername())
                .updated(updated)
                .build();
    }

    /** Map RoleCode → UserRole (tiện API / tích hợp login). */
    public UserRole mapRoleCode(String roleCode) {
        return SsoUserRoleMapper.toUserRole(roleCode);
    }

    private Optional<UserAccount> findLocalUser(String requestedPhone, String ssoPhone) {
        for (String candidate : usernameCandidates(requestedPhone, ssoPhone)) {
            Optional<UserAccount> found = userAccountRepository.findByUsername(candidate);
            if (found.isPresent()) {
                return found;
            }
        }
        return Optional.empty();
    }

    static Set<String> usernameCandidates(String... phones) {
        Set<String> out = new LinkedHashSet<>();
        for (String phone : phones) {
            if (phone == null || phone.isBlank()) {
                continue;
            }
            out.add(phone.trim());
            String digits = phone.replaceAll("\\D", "");
            if (!digits.isEmpty()) {
                out.add(digits);
                if (digits.startsWith("84") && digits.length() >= 11) {
                    out.add("0" + digits.substring(2));
                }
                if (digits.startsWith("0") && digits.length() >= 10) {
                    out.add("84" + digits.substring(1));
                }
            }
        }
        return out;
    }
}
