package com.minhan.hrm.service;

import com.minhan.hrm.entity.EmployeeContinuousShiftDay;
import com.minhan.hrm.repository.EmployeeContinuousShiftDayRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ContinuousShiftService {

    private final EmployeeContinuousShiftDayRepository repository;

    @Transactional(readOnly = true)
    public boolean isContinuousShift(Long employeeId, LocalDate date) {
        if (employeeId == null || date == null) {
            return false;
        }
        return repository.existsByEmployeeIdAndWorkDate(employeeId, date);
    }

    /** Còn ít nhất một ngày thông tầm trong tháng (UI / nhãn). */
    @Transactional(readOnly = true)
    public boolean isContinuousShiftMonth(Long employeeId, int year, int month) {
        if (employeeId == null) {
            return false;
        }
        YearMonth ym = YearMonth.of(year, month);
        return !repository.findByEmployeeIdAndWorkDateBetween(
                employeeId, ym.atDay(1), ym.atEndOfMonth()).isEmpty();
    }

    @Transactional(readOnly = true)
    public List<LocalDate> datesInMonth(Long employeeId, int year, int month) {
        if (employeeId == null) {
            return List.of();
        }
        YearMonth ym = YearMonth.of(year, month);
        return repository.findByEmployeeIdAndWorkDateBetween(employeeId, ym.atDay(1), ym.atEndOfMonth())
                .stream()
                .map(EmployeeContinuousShiftDay::getWorkDate)
                .sorted()
                .toList();
    }

    /**
     * Cache keys dạng {@code employeeId|yyyy-MM-dd} — tránh N+1 khi import/tính lại hàng loạt.
     */
    @Transactional(readOnly = true)
    public Set<String> dayKeysForEmployees(Collection<Long> employeeIds, LocalDate from, LocalDate to) {
        Set<String> keys = new HashSet<>();
        if (employeeIds == null || employeeIds.isEmpty() || from == null || to == null) {
            return keys;
        }
        for (EmployeeContinuousShiftDay row : repository.findByEmployeeIdInAndWorkDateBetween(
                employeeIds, from, to)) {
            keys.add(dayKey(row.getEmployeeId(), row.getWorkDate()));
        }
        return keys;
    }

    /** @deprecated dùng {@link #dayKeysForEmployees} */
    @Transactional(readOnly = true)
    public Set<String> monthKeysForEmployees(Collection<Long> employeeIds, LocalDate from, LocalDate to) {
        return dayKeysForEmployees(employeeIds, from, to);
    }

    public static String dayKey(Long employeeId, LocalDate date) {
        return employeeId + "|" + date;
    }

    public static String monthKey(Long employeeId, int year, int month) {
        return employeeId + "|" + year + "|" + month;
    }

    public static String monthKey(Long employeeId, LocalDate date) {
        return dayKey(employeeId, date);
    }

    @Transactional
    public List<LocalDate> replaceMonthDates(Long employeeId, int year, int month, Collection<LocalDate> dates) {
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        repository.deleteByEmployeeIdAndWorkDateBetween(employeeId, from, to);
        Set<LocalDate> unique = new HashSet<>();
        if (dates != null) {
            for (LocalDate d : dates) {
                if (d != null && !d.isBefore(from) && !d.isAfter(to)) {
                    unique.add(d);
                }
            }
        }
        List<EmployeeContinuousShiftDay> rows = new ArrayList<>();
        for (LocalDate d : unique) {
            rows.add(EmployeeContinuousShiftDay.builder()
                    .employeeId(employeeId)
                    .workDate(d)
                    .build());
        }
        if (!rows.isEmpty()) {
            repository.saveAll(rows);
        }
        return unique.stream().sorted().collect(Collectors.toList());
    }

    /** Tương thích API cũ: bật cả tháng / tắt hết tháng. */
    @Transactional
    public void setContinuousShiftMonth(Long employeeId, int year, int month, boolean enabled) {
        YearMonth ym = YearMonth.of(year, month);
        if (!enabled) {
            replaceMonthDates(employeeId, year, month, List.of());
            return;
        }
        List<LocalDate> all = new ArrayList<>();
        for (int d = 1; d <= ym.lengthOfMonth(); d++) {
            all.add(ym.atDay(d));
        }
        replaceMonthDates(employeeId, year, month, all);
    }
}
