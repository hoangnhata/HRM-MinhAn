package com.minhan.hrm.assistant;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.exception.ApiException;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class HrAssistantRateLimiterTest {

    @Test
    void blocksRequestsBeyondConfiguredLimitPerUser() {
        HrmProperties properties = new HrmProperties();
        properties.getAssistant().setRateLimitPerMinute(2);
        HrAssistantRateLimiter limiter = new HrAssistantRateLimiter(
                properties, Clock.fixed(Instant.parse("2026-08-03T08:00:00Z"), ZoneOffset.UTC));

        assertThatCode(() -> limiter.check("nhanvien-a")).doesNotThrowAnyException();
        assertThatCode(() -> limiter.check("nhanvien-a")).doesNotThrowAnyException();
        assertThatThrownBy(() -> limiter.check("nhanvien-a"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("quá nhanh");

        assertThatCode(() -> limiter.check("nhanvien-b")).doesNotThrowAnyException();
    }
}
