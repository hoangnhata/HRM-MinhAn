package com.minhan.hrm.service;

import com.minhan.hrm.entity.EmployeeContinuousShiftMonth;
import com.minhan.hrm.repository.EmployeeContinuousShiftMonthRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class ContinuousShiftService {

    private final EmployeeContinuousShiftMonthRepository repository;

    @Transactional(readOnly = true)
    public boolean isContinuousShift(Long employeeId, LocalDate date) {
        if (employeeId == null || date == null) {
            return false;
        }
        return repository.existsByEmployeeIdAndPeriodYearAndPeriodMonth(
                employeeId, date.getYear(), date.getMonthValue());
    }

    @Transactional(readOnly = true)
    public boolean isContinuousShiftMonth(Long employeeId, int year, int month) {
        if (employeeId == null) {
            return false;
        }
        return repository.existsByEmployeeIdAndPeriodYearAndPeriodMonth(employeeId, year, month);
    }

    /** Tải trước các tháng ca thông tầm trong khoảng ngày — tránh N+1 khi import/tính lại hàng loạt. */
    @Transactional(readOnly = true)
    public Set<String> monthKeysForEmployees(Collection<Long> employeeIds, LocalDate from, LocalDate to) {
        Set<String> keys = new HashSet<>();
        if (employeeIds == null || employeeIds.isEmpty() || from == null || to == null) {
            return keys;
        }
        YearMonth startYm = YearMonth.from(from);
        YearMonth endYm = YearMonth.from(to);
        for (EmployeeContinuousShiftMonth row : repository.findByEmployeeIdIn(employeeIds)) {
            YearMonth ym = YearMonth.of(row.getPeriodYear(), row.getPeriodMonth());
            if (!ym.isBefore(startYm) && !ym.isAfter(endYm)) {
                keys.add(monthKey(row.getEmployeeId(), row.getPeriodYear(), row.getPeriodMonth()));
            }
        }
        return keys;
    }

    public static String monthKey(Long employeeId, int year, int month) {
        return employeeId + "|" + year + "|" + month;
    }

    public static String monthKey(Long employeeId, LocalDate date) {
        return monthKey(employeeId, date.getYear(), date.getMonthValue());
    }

    @Transactional
    public void setContinuousShiftMonth(Long employeeId, int year, int month, boolean enabled) {
        EmployeeContinuousShiftMonth.Pk pk = new EmployeeContinuousShiftMonth.Pk(employeeId, year, month);
        if (enabled) {
            if (!repository.existsById(pk)) {
                repository.save(EmployeeContinuousShiftMonth.builder()
                        .employeeId(employeeId)
                        .periodYear(year)
                        .periodMonth(month)
                        .build());
            }
        } else {
            repository.deleteById(pk);
        }
    }
}
