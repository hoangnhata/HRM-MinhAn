package com.minhan.hrm.scheduler;

import com.minhan.hrm.service.ProbationConversionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Mỗi sáng áp dụng các đơn chuyển chính thức đã duyệt đến ngày hiệu lực.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ProbationConversionScheduler {

    private final ProbationConversionService conversionService;

    @Scheduled(cron = "0 15 0 * * *")
    public void applyDueConversions() {
        int n = conversionService.applyDueConversions();
        if (n > 0) {
            log.info("Probation conversion scheduler: applied {} request(s)", n);
        }
    }
}
