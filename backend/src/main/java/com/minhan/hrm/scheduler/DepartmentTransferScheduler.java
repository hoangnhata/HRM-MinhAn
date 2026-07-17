package com.minhan.hrm.scheduler;

import com.minhan.hrm.service.DepartmentTransferService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Mỗi sáng áp dụng các đề nghị luân chuyển đã duyệt đến ngày hiệu lực.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DepartmentTransferScheduler {

    private final DepartmentTransferService transferService;

    @Scheduled(cron = "0 10 0 * * *")
    public void applyDueTransfers() {
        int n = transferService.applyDueTransfers();
        if (n > 0) {
            log.info("Department transfer scheduler: applied {} request(s)", n);
        }
    }
}
