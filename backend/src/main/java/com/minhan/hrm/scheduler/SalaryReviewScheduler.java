package com.minhan.hrm.scheduler;

import com.minhan.hrm.entity.SalaryInfo;
import com.minhan.hrm.repository.SalaryInfoRepository;
import com.minhan.hrm.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

/**
 * Định kỳ quét nhân viên đến kỳ xem xét lương và tạo thông báo nội bộ.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SalaryReviewScheduler {

    private final SalaryInfoRepository salaryInfoRepository;
    private final NotificationService notificationService;

    /** Chạy mỗi ngày lúc 07:00 (server timezone). */
    @Scheduled(cron = "0 0 7 * * *")
    @Transactional
    public void notifyUpcomingSalaryReviews() {
        LocalDate today = LocalDate.now();
        LocalDate horizon = today.plusDays(14);
        List<SalaryInfo> due = salaryInfoRepository.findByNextReviewDateBetween(today, horizon);
        log.info("Salary review scheduler: {} bản ghi trong khoảng {} — {}", due.size(), today, horizon);
        for (SalaryInfo s : due) {
            try {
                notificationService.notifySalaryReview(
                        s.getEmployee().getUser(),
                        s.getEmployee(),
                        "Ngày dự kiến xem xét: " + s.getNextReviewDate());
            } catch (Exception e) {
                log.warn("Không gửi thông báo lương cho employee {}: {}", s.getEmployee().getId(), e.getMessage());
            }
        }
    }
}
