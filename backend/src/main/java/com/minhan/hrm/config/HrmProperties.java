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
    private final Auth auth = new Auth();
    private final SalaryAccess salaryAccess = new SalaryAccess();
    private final Assistant assistant = new Assistant();
    private final Push push = new Push();

    @Getter
    @Setter
    public static class Push {
        /** Bật gửi FCM khi có thông báo mới. Cần credentials Firebase Admin. */
        private boolean enabled = false;
        /** Đường dẫn file service-account JSON (Firebase Admin). */
        private String credentialsPath = "";
    }

    @Getter
    @Setter
    public static class Assistant {
        /** Trợ lý chỉ hoạt động khi đã cấu hình API key ở backend. */
        private boolean enabled = false;
        private String baseUrl = "https://api.openai.com/v1";
        private String apiKey = "";
        private String model = "gpt-5.6-terra";
        /** Model thứ hai được thử khi model chính hết hạn mức (429). */
        private String fallbackModel = "";
        private String reasoningEffort = "low";
        private int maxToolCalls = 4;
        private int maxRounds = 5;
        private int rateLimitPerMinute = 15;
        private int connectTimeoutSeconds = 10;
        private int readTimeoutSeconds = 45;
    }

    @Getter
    @Setter
    public static class SalaryAccess {
        /** Mật khẩu riêng để ADMIN mở khóa xem/chỉnh sửa lương toàn bệnh viện. */
        private String password = "luongMA@123";
        /** Thời gian hiệu lực của phiên mở khóa. */
        private long expirationMs = 1_800_000L; // 30 phút
    }

    @Getter
    @Setter
    public static class Auth {
        /**
         * Một lần: đặt lại mật khẩu user {@code admin} = Admin@123 và bắt đổi MK.
         * Tắt ngay sau khi đăng nhập được.
         */
        private boolean resetAdminPassword = false;
    }

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
        private String password = "345321@Vn";
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
        /** Bật kết nối sso_db — tắt mặc định: đăng nhập/phân quyền local trên MySQL */
        private boolean enabled = false;
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
        /**
         * Bỏ qua lỗi chứng chỉ HTTPS tự ký khi Java gọi ERP (PKIX).
         * Trình duyệt vẫn vào ERP bình thường; JVM cần bật tùy chọn này nếu cert chưa có trong truststore.
         */
        private boolean trustInsecureSsl = true;
    }

    @Getter
    @Setter
    public static class Frontend {
        /** Phục vụ React build từ thư mục (cùng port 8080, không cần IIS) */
        private boolean enabled = false;
        private String dir = "C:/hrm/www";
    }
}
