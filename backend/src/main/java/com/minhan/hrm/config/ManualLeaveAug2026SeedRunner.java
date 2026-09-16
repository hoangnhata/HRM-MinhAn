package com.minhan.hrm.config;

import com.minhan.hrm.entity.AttendanceRequestStatus;
import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.AttendanceShiftScope;
import com.minhan.hrm.entity.AttendanceWorkRequest;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.repository.AttendanceWorkRequestRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.service.AttendanceWorkRequestService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

/**
 * Bổ sung nghỉ phép tháng 8/2026 cho 4 NV (nhập tay, không tạo đơn UI).
 * Idempotent theo mã NV + khoảng ngày + marker trong reason.
 * <p>
 * Bật: {@code MANUAL_LEAVE_SEED=true} (mặc định true) rồi restart backend.
 * Sau khi đã seed xong trên server: đặt {@code MANUAL_LEAVE_SEED=false}.
 */
@Slf4j
@Component
@Order(Integer.MAX_VALUE - 10)
@RequiredArgsConstructor
public class ManualLeaveAug2026SeedRunner implements ApplicationRunner {

    static final String REASON_MARKER = "[MANUAL_LEAVE_SEED_AUG2026]";

    private record LeaveSeed(String employeeCode, String fullName, LocalDate from, LocalDate to) {}

    private static final List<LeaveSeed> SEEDS = List.of(
            new LeaveSeed("040192038858", "Bùi Thị Bình", LocalDate.of(2026, 8, 14), LocalDate.of(2026, 8, 20)),
            new LeaveSeed("040196003881", "Trần Thị Linh", LocalDate.of(2026, 8, 3), LocalDate.of(2026, 8, 10)),
            new LeaveSeed("040190039639", "Nguyễn Thị Phượng", LocalDate.of(2026, 8, 10), LocalDate.of(2026, 8, 16)),
            new LeaveSeed("040192022931", "Luyện Thị Hà", LocalDate.of(2026, 8, 1), LocalDate.of(2026, 8, 4))
    );

    private final HrmProperties hrmProperties;
    private final EmployeeRepository employeeRepository;
    private final AttendanceWorkRequestRepository requestRepository;
    private final AttendanceWorkRequestService workRequestService;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        HrmProperties.ManualLeaveSeed cfg = hrmProperties.getManualLeaveSeed();
        if (cfg == null || !cfg.isEnabled()) {
            return;
        }

        log.info("Manual leave seed BAT — bổ sung phép 8/2026 (tắt MANUAL_LEAVE_SEED=false sau khi xong)");
        int created = 0;
        int skipped = 0;
        int missing = 0;

        for (LeaveSeed seed : SEEDS) {
            Employee emp = employeeRepository.findByEmployeeCode(seed.employeeCode()).orElse(null);
            if (emp == null) {
                missing++;
                log.warn("Manual leave seed: không tìm thấy NV mã={} ({})", seed.employeeCode(), seed.fullName());
                continue;
            }
            if (alreadySeeded(emp.getId(), seed)) {
                skipped++;
                continue;
            }
            AttendanceWorkRequest req = AttendanceWorkRequest.builder()
                    .employee(emp)
                    .requestType(AttendanceRequestType.LEAVE)
                    .workDate(seed.from())
                    .endDate(seed.to())
                    .shiftScope(AttendanceShiftScope.FULL_DAY)
                    .reason(REASON_MARKER + " " + seed.fullName()
                            + " " + seed.from() + " → " + seed.to())
                    .status(AttendanceRequestStatus.APPROVED)
                    .hrWaiveForgotFine(false)
                    .explanationKeepOriginalTimes(false)
                    .build();
            requestRepository.save(req);
            created++;
            log.info("Manual leave seed: +LEAVE {} ({}) {} → {}",
                    emp.getFullName(), seed.employeeCode(), seed.from(), seed.to());
        }

        if (created > 0 || skipped > 0) {
            var result = workRequestService.reapplyApprovedEffectsInRange(
                    LocalDate.of(2026, 8, 1), LocalDate.of(2026, 8, 31));
            log.info("Manual leave seed xong: created={}, skipped={}, missing={}, reapplied={}",
                    created, skipped, missing, result.get("reapplied"));
        } else {
            log.info("Manual leave seed: không có gì để áp (created=0, missing={})", missing);
        }
    }

    private boolean alreadySeeded(Long employeeId, LeaveSeed seed) {
        return requestRepository.findByEmployeeIdAndWorkDateBetween(
                        employeeId, seed.from(), seed.to()).stream()
                .anyMatch(r -> r.getRequestType() == AttendanceRequestType.LEAVE
                        && r.getStatus() == AttendanceRequestStatus.APPROVED
                        && seed.from().equals(r.getWorkDate())
                        && seed.to().equals(r.getEndDate() != null ? r.getEndDate() : r.getWorkDate())
                        && r.getReason() != null
                        && r.getReason().contains(REASON_MARKER));
    }
}
