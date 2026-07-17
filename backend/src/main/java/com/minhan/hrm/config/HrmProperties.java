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
    private final Chamcong chamcong = new Chamcong();
    private final Sso sso = new Sso();
    private final ErpAuth erpAuth = new ErpAuth();
    private final Frontend frontend = new Frontend();

    @Getter
    @Setter
    public static class Jwt {
        private String secret = "change-me";
        private long expirationMs = 28_800_000L; // 8 giờ
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
        private String defaultEmployeePassword = "123";
    }

    @Getter
    @Setter
    public static class Chamcong {
        /** Bật kết nối SQL Server máy chấm công và đồng bộ tự động */
        private boolean enabled = false;
        private String url = "jdbc:sqlserver://192.168.31.101:1433;databaseName=chamcong;encrypt=optional;trustServerCertificate=true";
        private String username = "sa";
        private String password = "323321@Vn";
        /** Bảng lịch sử quẹt thẻ — mặc định dbo.CheckInOut */
        private String table = "dbo.CheckInOut";
        /** Số ngày lùi lại mỗi lần đồng bộ thủ công (để bắt cả chỉnh sửa trễ) */
        private int lookbackDays = 7;
        /** Số ngày lùi khi tự động đồng bộ theo chu kỳ (nhẹ hơn lookbackDays) */
        private int autoLookbackDays = 2;
        /** Cron đồng bộ tự động — legacy, lịch thật lấy từ DB interval minutes */
        private String syncCron = "0 * * * * *";
    }

    @Getter
    @Setter
    public static class Sso {
        /** Bật kết nối sso_db (SQL Server) — Roles / UserAppRoles cho HRM */
        private boolean enabled = true;
        private String url = "jdbc:sqlserver://192.168.8.16:1433;databaseName=sso_db;encrypt=optional;trustServerCertificate=true";
        private String username = "sa";
        private String password = "123@lrco";
        /** Mã app trong dbo.Roles / UserAppRoles */
        private String appCode = "HRM";
        /** Tự tạo bảng Roles/UserAppRoles + seed 6 role khi khởi động */
        private boolean autoMigrate = true;
        /** Gán ADMIN/EMPLOYEE từ cột legacy roles nếu chưa có UserAppRoles */
        private boolean autoAssignDefaults = true;
    }

    @Getter
    @Setter
    public static class ErpAuth {
        /** Base URL API ERP (không dùng path /sso của giao diện web) */
        private String baseUrl = "https://erp.benhvienminhan.com";
        /** Base URL file/avatar ERP (Node :3000). Mặc định LAN — Apache public thường không serve /uploads. */
        private String assetBaseUrl = "http://192.168.8.16:3000";
        private String loginPath = "/api/auth/login";
        private String profilePath = "/api/auth/profile";
    }

    @Getter
    @Setter
    public static class Frontend {
        /** Phục vụ React build từ thư mục (cùng port 8080, không cần IIS) */
        private boolean enabled = false;
        private String dir = "C:/hrm/www";
    }
}
