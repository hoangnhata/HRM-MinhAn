package com.minhan.hrm.assistant;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.exception.ApiException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class HrAssistantRateLimiter {

    private final HrmProperties properties;
    private final Clock clock;
    private final ConcurrentHashMap<String, Deque<Long>> requests = new ConcurrentHashMap<>();

    @Autowired
    public HrAssistantRateLimiter(HrmProperties properties) {
        this(properties, Clock.systemUTC());
    }

    HrAssistantRateLimiter(HrmProperties properties, Clock clock) {
        this.properties = properties;
        this.clock = clock;
    }

    public void check(String username) {
        int limit = Math.max(1, properties.getAssistant().getRateLimitPerMinute());
        long now = clock.millis();
        long cutoff = now - 60_000L;
        Deque<Long> bucket = requests.computeIfAbsent(username, ignored -> new ArrayDeque<>());
        synchronized (bucket) {
            while (!bucket.isEmpty() && bucket.peekFirst() <= cutoff) {
                bucket.removeFirst();
            }
            if (bucket.size() >= limit) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS,
                        "Bạn gửi câu hỏi quá nhanh. Vui lòng thử lại sau ít phút.");
            }
            bucket.addLast(now);
        }
        if (requests.size() > 10_000) {
            requests.entrySet().removeIf(e -> {
                synchronized (e.getValue()) {
                    return e.getValue().isEmpty() || e.getValue().peekLast() <= cutoff;
                }
            });
        }
    }
}
