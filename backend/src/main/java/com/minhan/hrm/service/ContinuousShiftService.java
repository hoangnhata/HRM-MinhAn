package com.minhan.hrm.service;

import com.minhan.hrm.dto.attendance.ContinuousShiftDayAssignment;
import com.minhan.hrm.entity.ContinuousShiftType;
import com.minhan.hrm.entity.EmployeeContinuousShiftDay;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.ContinuousShiftTypeRepository;
import com.minhan.hrm.repository.EmployeeContinuousShiftDayRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ContinuousShiftService {

    private static final double CONTINUOUS_MIN_HOURS = 8.0;

    private final EmployeeContinuousShiftDayRepository repository;
    private final ContinuousShiftTypeRepository shiftTypeRepository;

    @Transactional(readOnly = true)
    public boolean isContinuousShift(Long employeeId, LocalDate date) {
        if (employeeId == null || date == null) {
            return false;
        }
        return findDay(employeeId, date)
                .map(row -> {
                    if (row.getShiftTypeId() == null) {
                        // Gán ngày cũ không gắn danh mục → coi là thông tầm
                        return true;
                    }
                    return shiftTypeRepository.findById(row.getShiftTypeId())
                            .map(ContinuousShiftType::isContinuous)
                            .orElse(true);
                })
                .orElse(false);
    }

    /** Có gán khung ca theo ngày (thông tầm hoặc sáng–chiều). */
    @Transactional(readOnly = true)
    public boolean hasDayAssignment(Long employeeId, LocalDate date) {
        if (employeeId == null || date == null) {
            return false;
        }
        return repository.existsByEmployeeIdAndWorkDate(employeeId, date);
    }

    @Transactional(readOnly = true)
    public Optional<EmployeeContinuousShiftDay> findDay(Long employeeId, LocalDate date) {
        if (employeeId == null || date == null) {
            return Optional.empty();
        }
        return repository.findById(new EmployeeContinuousShiftDay.Pk(employeeId, date));
    }

    @Transactional(readOnly = true)
    public Optional<ContinuousShiftType> findType(Long id) {
        return id == null ? Optional.empty() : shiftTypeRepository.findById(id);
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
        return daysInMonth(employeeId, year, month).stream()
                .map(EmployeeContinuousShiftDay::getWorkDate)
                .sorted()
                .toList();
    }

    @Transactional(readOnly = true)
    public List<EmployeeContinuousShiftDay> daysInMonth(Long employeeId, int year, int month) {
        if (employeeId == null) {
            return List.of();
        }
        YearMonth ym = YearMonth.of(year, month);
        return repository.findByEmployeeIdAndWorkDateBetween(
                employeeId, ym.atDay(1), ym.atEndOfMonth());
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> dayMapsInMonth(Long employeeId, int year, int month) {
        List<EmployeeContinuousShiftDay> rows = daysInMonth(employeeId, year, month);
        Map<Long, ContinuousShiftType> types = loadTypes(rows);
        return rows.stream()
                .sorted((a, b) -> a.getWorkDate().compareTo(b.getWorkDate()))
                .map(row -> toDayMap(row, types.get(row.getShiftTypeId())))
                .toList();
    }

    /**
     * Cache keys dạng {@code employeeId|yyyy-MM-dd} — chỉ ngày <strong>ca thông tầm</strong>
     * (SPLIT không đưa vào — tránh xử lý 2 lần quẹt nhầm).
     */
    @Transactional(readOnly = true)
    public Set<String> dayKeysForEmployees(Collection<Long> employeeIds, LocalDate from, LocalDate to) {
        Set<String> keys = new HashSet<>();
        if (employeeIds == null || employeeIds.isEmpty() || from == null || to == null) {
            return keys;
        }
        List<EmployeeContinuousShiftDay> rows = repository.findByEmployeeIdInAndWorkDateBetween(
                employeeIds, from, to);
        if (rows.isEmpty()) {
            return keys;
        }
        Map<Long, ContinuousShiftType> types = loadTypes(rows);
        for (EmployeeContinuousShiftDay row : rows) {
            ContinuousShiftType type = row.getShiftTypeId() != null ? types.get(row.getShiftTypeId()) : null;
            // Không có type / type liên tục → thông tầm; SPLIT thì bỏ qua
            if (type != null && type.isSplit()) {
                continue;
            }
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
        List<ContinuousShiftDayAssignment> assignments = new ArrayList<>();
        if (dates != null) {
            for (LocalDate d : dates) {
                if (d == null) {
                    continue;
                }
                ContinuousShiftDayAssignment a = new ContinuousShiftDayAssignment();
                a.setDate(d);
                assignments.add(a);
            }
        }
        return replaceMonthAssignments(employeeId, year, month, assignments).stream()
                .map(EmployeeContinuousShiftDay::getWorkDate)
                .sorted()
                .toList();
    }

    @Transactional
    public List<EmployeeContinuousShiftDay> replaceMonthAssignments(
            Long employeeId, int year, int month, Collection<ContinuousShiftDayAssignment> assignments) {
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        repository.deleteByEmployeeIdAndWorkDateBetween(employeeId, from, to);

        Map<LocalDate, ContinuousShiftDayAssignment> unique = new HashMap<>();
        if (assignments != null) {
            for (ContinuousShiftDayAssignment a : assignments) {
                if (a == null || a.getDate() == null) {
                    continue;
                }
                LocalDate d = a.getDate();
                if (d.isBefore(from) || d.isAfter(to)) {
                    continue;
                }
                unique.put(d, a);
            }
        }

        List<EmployeeContinuousShiftDay> rows = new ArrayList<>();
        for (Map.Entry<LocalDate, ContinuousShiftDayAssignment> e : unique.entrySet()) {
            rows.add(buildRow(employeeId, e.getKey(), e.getValue()));
        }
        if (!rows.isEmpty()) {
            repository.saveAll(rows);
        }
        return rows.stream()
                .sorted((a, b) -> a.getWorkDate().compareTo(b.getWorkDate()))
                .collect(Collectors.toList());
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

    private EmployeeContinuousShiftDay buildRow(Long employeeId, LocalDate date, ContinuousShiftDayAssignment a) {
        Long typeId = a.getShiftTypeId();
        LocalTime start = a.getContinuousStart();
        LocalTime end = a.getContinuousEnd();
        ContinuousShiftType type = null;
        if (typeId != null) {
            type = shiftTypeRepository.findById(typeId)
                    .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "Không tìm thấy khung ca #" + typeId));
            if (!type.isActive()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ca \"" + type.getName() + "\" đã ngừng dùng");
            }
            if (type.isSplit()) {
                if (start == null) {
                    start = type.getMorningStart() != null ? type.getMorningStart() : type.getStartTime();
                }
                if (end == null) {
                    end = type.getAfternoonEnd() != null ? type.getAfternoonEnd() : type.getEndTime();
                }
            } else {
                if (start == null) {
                    start = type.getStartTime();
                }
                if (end == null) {
                    end = type.getEndTime();
                }
            }
        }
        if (start != null || end != null) {
            if (start == null || end == null || !start.isBefore(end)) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Ngày " + date + ": giờ vào phải trước giờ ra");
            }
            if (type == null || type.isContinuous()) {
                double hours = Duration.between(start, end).toMinutes() / 60.0;
                if (hours < CONTINUOUS_MIN_HOURS) {
                    throw new ApiException(HttpStatus.BAD_REQUEST,
                            "Ngày " + date + ": ca thông tầm phải tối thiểu 8 giờ");
                }
            } else if (type.isSplit()) {
                LocalTime ms = type.getMorningStart();
                LocalTime me = type.getMorningEnd();
                LocalTime as = type.getAfternoonStart();
                LocalTime ae = type.getAfternoonEnd();
                if (ms == null || me == null || as == null || ae == null) {
                    throw new ApiException(HttpStatus.BAD_REQUEST,
                            "Ngày " + date + ": ca sáng–chiều chưa cấu hình đủ giờ");
                }
                double hours = Duration.between(ms, me).toMinutes() / 60.0
                        + Duration.between(as, ae).toMinutes() / 60.0;
                if (hours < CONTINUOUS_MIN_HOURS) {
                    throw new ApiException(HttpStatus.BAD_REQUEST,
                            "Ngày " + date + ": ca sáng–chiều phải tối thiểu 8 giờ");
                }
            }
        }
        return EmployeeContinuousShiftDay.builder()
                .employeeId(employeeId)
                .workDate(date)
                .shiftTypeId(typeId)
                .continuousStart(start)
                .continuousEnd(end)
                .build();
    }

    private Map<Long, ContinuousShiftType> loadTypes(List<EmployeeContinuousShiftDay> rows) {
        Set<Long> ids = rows.stream()
                .map(EmployeeContinuousShiftDay::getShiftTypeId)
                .filter(id -> id != null)
                .collect(Collectors.toSet());
        if (ids.isEmpty()) {
            return Map.of();
        }
        Map<Long, ContinuousShiftType> map = new HashMap<>();
        for (ContinuousShiftType t : shiftTypeRepository.findAllById(ids)) {
            map.put(t.getId(), t);
        }
        return map;
    }

    private Map<String, Object> toDayMap(EmployeeContinuousShiftDay row, ContinuousShiftType type) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("date", row.getWorkDate().toString());
        m.put("shiftTypeId", row.getShiftTypeId());
        m.put("shiftTypeName", type != null ? type.getName() : null);
        m.put("kind", type != null && type.isSplit() ? "SPLIT" : "CONTINUOUS");
        m.put("kindLabel", type != null && type.isSplit() ? "Ca sáng–chiều" : "Ca thông tầm");
        if (row.getContinuousStart() != null) {
            m.put("continuousStart", row.getContinuousStart().toString());
        } else if (type != null) {
            m.put("continuousStart", type.getStartTime().toString());
        } else {
            m.put("continuousStart", null);
        }
        if (row.getContinuousEnd() != null) {
            m.put("continuousEnd", row.getContinuousEnd().toString());
        } else if (type != null) {
            m.put("continuousEnd", type.getEndTime().toString());
        } else {
            m.put("continuousEnd", null);
        }
        if (type != null && type.isSplit()) {
            m.put("morningStart", type.getMorningStart() != null ? type.getMorningStart().toString() : null);
            m.put("morningEnd", type.getMorningEnd() != null ? type.getMorningEnd().toString() : null);
            m.put("afternoonStart", type.getAfternoonStart() != null ? type.getAfternoonStart().toString() : null);
            m.put("afternoonEnd", type.getAfternoonEnd() != null ? type.getAfternoonEnd().toString() : null);
        }
        return m;
    }
}
