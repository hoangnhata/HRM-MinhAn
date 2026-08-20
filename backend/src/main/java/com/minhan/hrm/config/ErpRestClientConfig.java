package com.minhan.hrm.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import java.net.http.HttpClient;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.time.Duration;

/**
 * RestClient gọi API ERP — có thể bỏ qua lỗi chứng chỉ HTTPS tự ký (LAN / dev).
 */
@Slf4j
@Configuration
public class ErpRestClientConfig {

    @Bean
    RestClient erpRestClient(HrmProperties hrmProperties) {
        RestClient.Builder builder = RestClient.builder();
        if (hrmProperties.getErpAuth().isTrustInsecureSsl()) {
            log.warn(
                    "ERP trust-insecure-ssl=true — bỏ qua xác thực chứng chỉ HTTPS khi gọi {} (chỉ dùng dev/LAN)",
                    hrmProperties.getErpAuth().getBaseUrl());
            builder.requestFactory(insecureSslRequestFactory());
        }
        return builder.build();
    }

    private static ClientHttpRequestFactory insecureSslRequestFactory() {
        try {
            TrustManager[] trustAll = new TrustManager[]{
                    new X509TrustManager() {
                        @Override
                        public void checkClientTrusted(X509Certificate[] chain, String authType) {
                        }

                        @Override
                        public void checkServerTrusted(X509Certificate[] chain, String authType) {
                        }

                        @Override
                        public X509Certificate[] getAcceptedIssuers() {
                            return new X509Certificate[0];
                        }
                    }
            };
            SSLContext sslContext = SSLContext.getInstance("TLS");
            sslContext.init(null, trustAll, new SecureRandom());

            HttpClient httpClient = HttpClient.newBuilder()
                    .sslContext(sslContext)
                    .connectTimeout(Duration.ofSeconds(15))
                    .build();
            JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
            factory.setReadTimeout(Duration.ofSeconds(30));
            return factory;
        } catch (Exception e) {
            throw new IllegalStateException("Không tạo được RestClient ERP (SSL)", e);
        }
    }
}
