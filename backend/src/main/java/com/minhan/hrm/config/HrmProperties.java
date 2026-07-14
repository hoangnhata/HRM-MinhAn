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
    private final Frontend frontend = new Frontend();

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
        /** Số ngày lùi lại mỗi lần đồng bộ (để bắt cả chỉnh sửa trễ) */
        private int lookbackDays = 7;
        /** Cron đồng bộ tự động — mặc định 01:30 hàng ngày */
        private String syncCron = "0 30 1 * * *";
    }

    @Getter
    @Setter
    public static class Frontend {
        /** Phục vụ React build từ thư mục (cùng port 8080, không cần IIS) */
        private boolean enabled = false;
        private String dir = "C:/hrm/www";
    }
}
