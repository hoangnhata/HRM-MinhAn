package com.minhan.hrm.config;

import java.security.Security;

/**
 * SQL Server 2014 (máy chấm công) thường chỉ hỗ trợ TLS 1.0 — Java 17 mặc định từ chối.
 */
public final class LegacySqlServerTls {

    private LegacySqlServerTls() {}

    public static void enableForSqlServer2014() {
        try {
            String disabled = Security.getProperty("jdk.tls.disabledAlgorithms");
            if (disabled != null && !disabled.isBlank()) {
                String relaxed = disabled
                        .replace("TLSv1, ", "")
                        .replace("TLSv1.1, ", "")
                        .replace("TLSv1,", "")
                        .replace("TLSv1.1,", "");
                Security.setProperty("jdk.tls.disabledAlgorithms", relaxed);
            }
            System.setProperty("jdk.tls.client.protocols", "TLSv1.2,TLSv1.1,TLSv1");
        } catch (Exception ignored) {
            System.setProperty("jdk.tls.client.protocols", "TLSv1.2,TLSv1.1,TLSv1");
        }
    }
}
