package com.minhan.hrm.sso;

import com.minhan.hrm.config.HrmProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@Order(50)
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
public class SsoSchemaInitializer implements ApplicationRunner {

    private final SsoRoleService ssoRoleService;
    private final HrmProperties hrmProperties;

    @Override
    public void run(ApplicationArguments args) {
        HrmProperties.Sso cfg = hrmProperties.getSso();
        try {
            if (cfg.isAutoMigrate()) {
                ssoRoleService.ensureSchemaAndSeedRoles();
                ssoRoleService.ensureAccountProvisioningColumns();
            }
            if (cfg.isAutoAssignDefaults()) {
                int n = ssoRoleService.assignDefaultsFromLegacyRoles();
                if (n > 0) {
                    log.info("SSO assigned default HRM roles for {} account(s)", n);
                }
            }
        } catch (Exception e) {
            log.warn("SSO schema/assign skipped (DB chưa sẵn sàng?): {}", e.getMessage());
        }
    }
}
