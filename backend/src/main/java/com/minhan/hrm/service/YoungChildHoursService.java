package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceShiftSchedule;
import com.minhan.hrm.entity.EmployeeYoungChildPeriod;
import com.minhan.hrm.repository.EmployeeYoungChildPeriodRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class YoungChildHoursService {

    /** Tối thiểu giờ/ngày = 1 công khi nuôi con nhỏ. */
    public static final double MAX_DAY_HOURS = 7.0;
    public static final int REDUCTION_HOURS = 1;
    public static final LocalDate OPEN_ENDED_DATE = LocalDate.of(9999, 12, 31);

    private final EmployeeYoungChildPeriodRepository repository;

    @Transactional(readOnly = true)
    public boolean isYoungChild(Long employeeId, LocalDate date) {
        if (employeeId == null || date == null) {
            return false;
        }
        return repository.existsByEmployeeIdAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
                employeeId, date, date);
    }

    @Transactional(readOnly = true)
    public boolean isYoungChildMonth(Long employeeId, int year, int month) {
        if (employeeId == null) {
            return false;
        }
        java.time.YearMonth ym = java.time.YearMonth.of(year, month);
        return !repository.findOverlapping(employeeId, ym.atDay(1), ym.atEndOfMonth()).isEmpty();
    }

    @Transactional(readOnly = true)
    public Set<String> dateKeysForEmployees(Collection<Long> employeeIds, LocalDate from, LocalDate to) {
        Set<String> keys = new HashSet<>();
        if (employeeIds == null || employeeIds.isEmpty() || from == null || to == null) {
            return keys;
        }
        for (EmployeeYoungChildPeriod row : repository.findOverlappingForEmployees(employeeIds, from, to)) {
            LocalDate start = row.getStartDate().isBefore(from) ? from : row.getStartDate();
            LocalDate end = row.getEndDate().isAfter(to) ? to : row.getEndDate();
            for (LocalDate date = start; !date.isAfter(end); date = date.plusDays(1)) {
                keys.add(dateKey(row.getEmployeeId(), date));
            }
        }
        return keys;
    }

    public static String dateKey(Long employeeId, LocalDate date) {
        return employeeId + "|" + date;
    }

    @Transactional(readOnly = true)
    public Set<LocalDate> datesForEmployee(Long employeeId, LocalDate from, LocalDate to) {
        Set<LocalDate> dates = new HashSet<>();
        for (EmployeeYoungChildPeriod row : repository.findOverlapping(employeeId, from, to)) {
            LocalDate start = row.getStartDate().isBefore(from) ? from : row.getStartDate();
            LocalDate end = row.getEndDate().isAfter(to) ? to : row.getEndDate();
            for (LocalDate date = start; !date.isAfter(end); date = date.plusDays(1)) dates.add(date);
        }
        return dates;
    }

    /** Giờ ngày hiệu lực cho quy đổi công (tối thiểu 7). */
    public static double effectiveDayHours(double baseDayHours) {
        if (baseDayHours <= 0) {
            return MAX_DAY_HOURS;
        }
        return Math.max(baseDayHours - REDUCTION_HOURS, MAX_DAY_HOURS);
    }

    /**
     * Giảm 1 giờ cuối ngày (về sớm được phép): lùi {@code afternoonEnd} và {@code continuousEnd},
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
        LocalTime contStart = base.continuousDayStart();
        LocalTime newContEnd = base.continuousDayEnd().minusHours(REDUCTION_HOURS);
        if (!newContEnd.isAfter(contStart)) {
            newContEnd = contStart.plusMinutes(Math.round(MAX_DAY_HOURS * 60));
        }
        double contHours = Duration.between(contStart, newContEnd).toMinutes() / 60.0;
        if (contHours < MAX_DAY_HOURS) {
            newContEnd = contStart.plusMinutes(Math.round(MAX_DAY_HOURS * 60));
        }
        return new AttendanceShiftSchedule(
                base.morningStart(),
                base.morningEnd(),
                base.afternoonStart(),
                newEnd,
                contStart,
                newContEnd,
                base.morningUnits(),
                base.afternoonUnits(),
                base.summer(),
                morningHours,
                afternoonHours,
                base.punchWindows());
    }

    @Transactional
    public void setYoungChildPeriod(Long employeeId, LocalDate startDate, LocalDate endDate, boolean enabled) {
        List<EmployeeYoungChildPeriod> overlaps = new ArrayList<>(
                repository.findOverlapping(employeeId, startDate.minusDays(1), endDate.plusDays(1)));
        if (enabled) {
            LocalDate mergedStart = startDate;
            LocalDate mergedEnd = endDate;
            for (EmployeeYoungChildPeriod row : overlaps) {
                if (row.getStartDate().isBefore(mergedStart)) mergedStart = row.getStartDate();
                if (row.getEndDate().isAfter(mergedEnd)) mergedEnd = row.getEndDate();
            }
            repository.deleteAll(overlaps);
            repository.save(EmployeeYoungChildPeriod.builder()
                    .employeeId(employeeId).startDate(mergedStart).endDate(mergedEnd).build());
            return;
        }

        List<EmployeeYoungChildPeriod> replacements = new ArrayList<>();
        for (EmployeeYoungChildPeriod row : repository.findOverlapping(employeeId, startDate, endDate)) {
            if (row.getStartDate().isBefore(startDate)) {
                replacements.add(EmployeeYoungChildPeriod.builder()
                        .employeeId(employeeId).startDate(row.getStartDate()).endDate(startDate.minusDays(1)).build());
            }
            if (row.getEndDate().isAfter(endDate)) {
                replacements.add(EmployeeYoungChildPeriod.builder()
                        .employeeId(employeeId).startDate(endDate.plusDays(1)).endDate(row.getEndDate()).build());
            }
            repository.delete(row);
        }
        repository.saveAll(replacements);
    }

    @Transactional
    public void setYoungChildMonth(Long employeeId, int year, int month, boolean enabled) {
        java.time.YearMonth ym = java.time.YearMonth.of(year, month);
        setYoungChildPeriod(employeeId, ym.atDay(1), ym.atEndOfMonth(), enabled);
    }

    /** ADMIN bật từ một ngày đến khi chủ động tắt; khi tắt vẫn giữ lịch sử trước ngày hiệu lực. */
    @Transactional
    public void setYoungChildOpenEnded(Long employeeId, LocalDate effectiveDate, boolean enabled) {
        if (enabled) {
            if (isYoungChild(employeeId, effectiveDate)) return;
            List<EmployeeYoungChildPeriod> future = repository.findOverlapping(
                    employeeId, effectiveDate.minusDays(1), OPEN_ENDED_DATE);
            LocalDate start = effectiveDate;
            for (EmployeeYoungChildPeriod row : future) {
                if (row.getStartDate().isBefore(start)) start = row.getStartDate();
            }
            repository.deleteAll(future);
            repository.save(EmployeeYoungChildPeriod.builder()
                    .employeeId(employeeId).startDate(start).endDate(OPEN_ENDED_DATE).build());
            return;
        }

        List<EmployeeYoungChildPeriod> affected = repository.findOverlapping(
                employeeId, effectiveDate, OPEN_ENDED_DATE);
        List<EmployeeYoungChildPeriod> history = new ArrayList<>();
        for (EmployeeYoungChildPeriod row : affected) {
            if (row.getStartDate().isBefore(effectiveDate)) {
                history.add(EmployeeYoungChildPeriod.builder()
                        .employeeId(employeeId)
                        .startDate(row.getStartDate())
                        .endDate(effectiveDate.minusDays(1))
                        .build());
            }
        }
        repository.deleteAll(affected);
        repository.saveAll(history);
    }
}
