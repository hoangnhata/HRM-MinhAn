package com.minhan.hrm.config;

import com.minhan.hrm.service.RequesterSignatureBackfillService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

/** Gắn chữ ký người lập vào đơn cũ ngay sau khi khởi động. */
@Slf4j
@Component
@Order(50)
@RequiredArgsConstructor
public class RequesterSignatureBackfillRunner implements ApplicationRunner {

    private final RequesterSignatureBackfillService backfillService;

    @Override
    public void run(ApplicationArguments args) {
        try {
            backfillService.backfillMissing();
        } catch (Exception ex) {
            log.warn("Không bổ sung được chữ ký người lập cho đơn cũ: {}", ex.getMessage());
        }
    }
}
