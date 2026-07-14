package com.minhan.hrm.service;

import com.minhan.hrm.dto.attendance.HolidayWorkDaysUpdateRequest;
import com.minhan.hrm.entity.AttendanceHolidayWorkDay;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.AttendanceHolidayWorkDayRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class HolidayWorkDayService {

    private final AttendanceHolidayWorkDayRepository repository;

    @Transactional(readOnly = true)
    public boolean isHoliday(LocalDate date) {
        if (date == null) {
            return false;
        }
        return repository.existsByWorkDate(date);
    }

    @Transactional(readOnly = true)
    public Set<LocalDate> datesInRange(LocalDate from, LocalDate to) {
        return repository.findByWorkDateBetweenOrderByWorkDateAsc(from, to).stream()
                .map(AttendanceHolidayWorkDay::getWorkDate)
                .collect(Collectors.toSet());
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional(readOnly = true)
    public Map<String, Object> listForMonth(int year, int month) {
        YearMonth ym = requireYearMonth(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        List<String> dates = repository.findByWorkDateBetweenOrderByWorkDateAsc(from, to).stream()
                .map(d -> d.getWorkDate().toString())
                .toList();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("year", year);
        out.put("month", month);
        out.put("dates", dates);
        return out;
    }

    /**
     * Thay toàn bộ ngày lễ trong tháng bằng danh sách mới.
     * Ngày ngoài tháng bị bỏ qua.
     */
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> replaceMonth(HolidayWorkDaysUpdateRequest req) {
        YearMonth ym = requireYearMonth(req.getYear(), req.getMonth());
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        repository.deleteByWorkDateBetween(from, to);
        List<LocalDate> valid = req.getDates() == null ? List.of() : req.getDates().stream()
                .filter(d -> d != null && !d.isBefore(from) && !d.isAfter(to))
                .distinct()
                .sorted()
                .toList();
        for (LocalDate d : valid) {
            repository.save(AttendanceHolidayWorkDay.builder().workDate(d).build());
        }
        return listForMonth(req.getYear(), req.getMonth());
    }

    private static YearMonth requireYearMonth(int year, int month) {
        if (month < 1 || month > 12) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Tháng không hợp lệ");
        }
        return YearMonth.of(year, month);
    }
}
