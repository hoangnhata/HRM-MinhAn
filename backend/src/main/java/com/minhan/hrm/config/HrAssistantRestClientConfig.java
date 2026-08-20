package com.minhan.hrm.config;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.net.http.HttpClient;
import java.time.Duration;

@Configuration
public class HrAssistantRestClientConfig {

    @Bean
    @Qualifier("hrAssistantRestClient")
    RestClient hrAssistantRestClient(HrmProperties properties) {
        HrmProperties.Assistant cfg = properties.getAssistant();
        HttpClient httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(Math.max(1, cfg.getConnectTimeoutSeconds())))
                .build();
        JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
        requestFactory.setReadTimeout(Duration.ofSeconds(Math.max(1, cfg.getReadTimeoutSeconds())));
        return RestClient.builder()
                .baseUrl(cfg.getBaseUrl())
                .requestFactory(requestFactory)
                .build();
    }
}
