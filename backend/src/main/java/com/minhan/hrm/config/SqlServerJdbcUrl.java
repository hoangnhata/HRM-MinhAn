package com.minhan.hrm.config;

/** Chuẩn hóa JDBC URL SQL Server (encrypt / trustServerCertificate). */
public final class SqlServerJdbcUrl {

    private SqlServerJdbcUrl() {}

    public static String build(String configuredUrl) {
        if (configuredUrl == null || configuredUrl.isBlank()) {
            return configuredUrl;
        }
        String url = configuredUrl.trim();
        if (!url.contains("encrypt=")) {
            url = append(url, "encrypt=optional");
        }
        if (!url.contains("trustServerCertificate=")) {
            url = append(url, "trustServerCertificate=true");
        }
        return url;
    }

    private static String append(String url, String param) {
        char sep = url.contains(";") ? ';' : '?';
        return url + sep + param;
    }
}
