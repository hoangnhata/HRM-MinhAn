package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceShiftSchedule;
import com.minhan.hrm.entity.EmployeeYoungChildMonth;
import com.minhan.hrm.repository.EmployeeYoungChildMonthRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.YearMonth;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class YoungChildHoursService {

    /** Tối thiểu giờ/ngày = 1 công khi nuôi con nhỏ. */
    public static final double MAX_DAY_HOURS = 7.0;
    public static final int REDUCTION_HOURS = 1;

    private final EmployeeYoungChildMonthRepository repository;

    @Transactional(readOnly = true)
    public boolean isYoungChild(Long employeeId, LocalDate date) {
        if (employeeId == null || date == null) {
            return false;
        }
        return repository.existsByEmployeeIdAndPeriodYearAndPeriodMonth(
                employeeId, date.getYear(), date.getMonthValue());
    }

    @Transactional(readOnly = true)
    public boolean isYoungChildMonth(Long employeeId, int year, int month) {
        if (employeeId == null) {
            return false;
        }
        return repository.existsByEmployeeIdAndPeriodYearAndPeriodMonth(employeeId, year, month);
    }

    @Transactional(readOnly = true)
    public Set<String> monthKeysForEmployees(Collection<Long> employeeIds, LocalDate from, LocalDate to) {
        Set<String> keys = new HashSet<>();
        if (employeeIds == null || employeeIds.isEmpty() || from == null || to == null) {
            return keys;
        }
        YearMonth startYm = YearMonth.from(from);
        YearMonth endYm = YearMonth.from(to);
        for (EmployeeYoungChildMonth row : repository.findByEmployeeIdIn(employeeIds)) {
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

    /** Giờ ngày hiệu lực cho quy đổi công (tối thiểu 7). */
    public static double effectiveDayHours(double baseDayHours) {
        if (baseDayHours <= 0) {
            return MAX_DAY_HOURS;
        }
        return Math.max(baseDayHours - REDUCTION_HOURS, MAX_DAY_HOURS);
    }

    /**
     * Giảm 1 giờ cuối ngày (về sớm được phép): lùi {@code afternoonEnd},
     * tổng giờ ngày = max(gốc − 1, 7).
     */
    public static AttendanceShiftSchedule applyReduction(AttendanceShiftSchedule base) {
        LocalTime newEnd = base.afternoonEnd().minusHours(REDUCTION_HOURS);
        if (!newEnd.isAfter(base.afternoonStart())) {
            newEnd = base.afternoonStart().plusMinutes(30);
        }
        double afternoonHours = Duration.between(base.afternoonStart(), newEnd).toMinutes() / 60.0;
        double morningHours = base.morningHours();
        double total = morningHours + afternoonHours;
        if (total < MAX_DAY_HOURS && morningHours > 0) {
            // giữ tối thiểu 7h bằng cách không rút quá mức
            double need = MAX_DAY_HOURS - morningHours;
            if (need > 0) {
                newEnd = base.afternoonStart().plusMinutes(Math.round(need * 60));
                afternoonHours = need;
            }
        }
        return new AttendanceShiftSchedule(
                base.morningStart(),
                base.morningEnd(),
                base.afternoonStart(),
                newEnd,
                base.morningUnits(),
                base.afternoonUnits(),
                base.summer(),
                morningHours,
                afternoonHours,
                base.punchWindows());
    }

    @Transactional
    public void setYoungChildMonth(Long employeeId, int year, int month, boolean enabled) {
        EmployeeYoungChildMonth.Pk pk = new EmployeeYoungChildMonth.Pk(employeeId, year, month);
        if (enabled) {
            if (!repository.existsById(pk)) {
                repository.save(EmployeeYoungChildMonth.builder()
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
