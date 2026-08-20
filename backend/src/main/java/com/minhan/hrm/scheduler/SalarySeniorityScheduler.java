package com.minhan.hrm.scheduler;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeSalaryProfile;
import com.minhan.hrm.entity.SalaryCategory;
import com.minhan.hrm.repository.EmployeeSalaryProfileRepository;
import com.minhan.hrm.service.NotificationService;
import com.minhan.hrm.service.SalaryCalculatorService;
import com.minhan.hrm.dto.salary.ComputedSalaryGradeDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Mồng 1 hàng tháng: thâm niên tự +1/12 (tính trên đọc), kiểm tra bậc lương nhảy
 * theo thâm niên và gửi thông báo.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SalarySeniorityScheduler {

    private final EmployeeSalaryProfileRepository profileRepository;
    private final SalaryCalculatorService salaryCalculator;
    private final NotificationService notificationService;

    /** 01:15 sáng ngày 1 hàng tháng. */
    @Scheduled(cron = "0 15 1 1 * *")
    @Transactional
    public void onMonthStartBumpGrades() {
        LocalDate today = LocalDate.now();
        List<EmployeeSalaryProfile> profiles = profileRepository.findAll();
        int notified = 0;
        for (EmployeeSalaryProfile profile : profiles) {
            if (profile.isLdg() || profile.getSalaryCategory() != SalaryCategory.EMPLOYEE) {
                continue;
            }
            if (profile.getBaseSeniorityYears() == null && profile.getSalaryScaleStartDate() == null) {
                continue;
            }
            Employee emp = profile.getEmployee();
            if (emp == null || emp.getUser() == null) {
                continue;
            }
            try {
                BigDecimal seniority = salaryCalculator.resolveSeniorityYears(emp, profile, today);
                int newGrade = salaryCalculator.calculateGrade(seniority);
                int oldGrade = profile.getLastNotifiedGrade();
                if (newGrade > 0 && newGrade > oldGrade) {
                    ComputedSalaryGradeDto g = salaryCalculator.computeForProfile(emp, profile);
                    notificationService.notifySalaryGradeIncrease(
                            emp.getUser(), emp, oldGrade, newGrade,
                            g.getYearsRange() != null ? g.getYearsRange()
                                    : salaryCalculator.yearsRangeForGrade(newGrade));
                    profile.setLastNotifiedGrade(newGrade);
                    profileRepository.save(profile);
                    notified++;
                } else if (oldGrade == 0 && newGrade > 0) {
                    profile.setLastNotifiedGrade(newGrade);
                    profileRepository.save(profile);
                }
            } catch (Exception e) {
                log.warn("Seniority grade check failed for employee {}: {}",
                        emp.getId(), e.getMessage());
            }
        }
        log.info("Salary seniority month-start: scanned={}, notified={}", profiles.size(), notified);
    }
}
