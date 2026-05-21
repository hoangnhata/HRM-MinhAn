package com.minhan.hrm.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "minhan.hrm")
public class HrmProperties {

    private final Jwt jwt = new Jwt();
    private final Upload upload = new Upload();
    private final ImportConfig importConfig = new ImportConfig();

    @Getter
    @Setter
    public static class Jwt {
        private String secret = "change-me";
        private long expirationMs = 86400000L;
    }

    @Getter
    @Setter
    public static class Upload {
        private String dir = "./data/uploads";
    }

    @Getter
    @Setter
    public static class ImportConfig {
        /** Mật khẩu mặc định cho user EMPLOYEE tạo từ import Excel */
        private String defaultEmployeePassword = "Minhan@123";
    }
}
