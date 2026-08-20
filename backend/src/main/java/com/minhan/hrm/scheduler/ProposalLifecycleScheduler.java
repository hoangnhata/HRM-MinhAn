package com.minhan.hrm.scheduler;

import com.minhan.hrm.service.SeminarProposalService;
import com.minhan.hrm.service.TrainingProposalService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Mỗi sáng tự động hoàn thành phiếu đào tạo / hội thảo đã hết thời gian và gửi thông báo.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ProposalLifecycleScheduler {

    private final TrainingProposalService trainingProposalService;
    private final SeminarProposalService seminarProposalService;

    @Scheduled(cron = "0 20 0 * * *")
    public void completeDueProposals() {
        int training = trainingProposalService.completeDueProposals();
        int seminar = seminarProposalService.completeDueProposals();
        if (training > 0 || seminar > 0) {
            log.info("Proposal lifecycle scheduler: completed {} training, {} seminar proposal(s)",
                    training, seminar);
        }
    }
}
