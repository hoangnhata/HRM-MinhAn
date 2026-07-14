package com.minhan.hrm.config;

final class ChamcongJdbcUrl {

    private ChamcongJdbcUrl() {}

    static String build(String configuredUrl) {
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
