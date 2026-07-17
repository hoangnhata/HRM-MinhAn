package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendancePunchWindows;
import com.minhan.hrm.attendance.AttendanceShiftSchedule;
import com.minhan.hrm.dto.attendance.AttendanceShiftConfigUpdateRequest;
import com.minhan.hrm.entity.AttendanceShiftConfig;
import com.minhan.hrm.entity.AttendanceShiftSeason;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeAttendanceShiftConfig;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.AttendanceShiftConfigRepository;
import com.minhan.hrm.repository.EmployeeAttendanceShiftConfigRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AttendanceShiftScheduleService {

    private final AttendanceShiftConfigRepository configRepository;
    private final EmployeeAttendanceShiftConfigRepository employeeConfigRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeService employeeService;
    private final ContinuousShiftService continuousShiftService;
    private final YoungChildHoursService youngChildHoursService;

    private volatile Map<AttendanceShiftSeason, AttendanceShiftConfig> cached = new EnumMap<>(AttendanceShiftSeason.class);

    @PostConstruct
    void init() {
        reloadCache();
    }

    @Transactional(readOnly = true)
    public AttendanceShiftSchedule forDate(LocalDate date) {
        AttendanceShiftSeason season = AttendanceShiftSchedule.isSummer(date)
                ? AttendanceShiftSeason.SUMMER
                : AttendanceShiftSeason.WINTER;
        AttendanceShiftConfig cfg = requireConfig(season);
        return toSchedule(cfg, season == AttendanceShiftSeason.SUMMER);
    }

    /** Lịch ca theo nhân viên (áp dụng giảm giờ nuôi con nhỏ nếu có). */
    @Transactional(readOnly = true)
    public AttendanceShiftSchedule forEmployee(Long employeeId, LocalDate date) {
        AttendanceShiftSeason season = AttendanceShiftSchedule.isSummer(date)
                ? AttendanceShiftSeason.SUMMER
                : AttendanceShiftSeason.WINTER;
        AttendanceShiftSchedule base = employeeId == null
                ? toSchedule(requireConfig(season), season == AttendanceShiftSeason.SUMMER)
                : employeeConfigRepository.findByEmployee_IdAndSeason(employeeId, season)
                        .map(cfg -> toSchedule(cfg, season == AttendanceShiftSeason.SUMMER))
                        .orElseGet(() -> toSchedule(requireConfig(season), season == AttendanceShiftSeason.SUMMER));
        if (employeeId != null && youngChildHoursService.isYoungChild(employeeId, date)) {
            return YoungChildHoursService.applyReduction(base);
        }
        return base;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> infoForDate(LocalDate date, Long employeeId) {
        AttendanceShiftSchedule schedule = forEmployee(employeeId, date);
        Map<String, Object> info = new LinkedHashMap<>(schedule.toInfoMap());
        info.put("referenceDate", date.toString());
        info.put("periodYear", date.getYear());
        info.put("periodMonth", date.getMonthValue());
        boolean youngChild = false;
        boolean continuous = false;
        if (employeeId != null) {
            employeeService.requireEmployeeEntity(employeeId);
            continuous = continuousShiftService.isContinuousShift(employeeId, date);
            youngChild = youngChildHoursService.isYoungChild(employeeId, date);
            info.put("continuousShift", continuous);
            info.put("youngChild", youngChild);
            if (continuous) {
                double continuousHours = schedule.continuousHours();
                info.put("continuousLabel", youngChild
                        ? "Ca thông tầm · nuôi con nhỏ (−1 giờ, tối thiểu 7h = 1 công)"
                        : "Ca thông tầm (không nghỉ trưa)");
                // Giữ morningHours / afternoonHours gốc để banner ca sáng/chiều không bị nhảy
                info.put("effectiveDayHours", continuousHours);
            } else {
                info.put("effectiveDayHours", schedule.totalHours());
                if (youngChild) {
                    info.put("youngChildLabel", "Nuôi con nhỏ · giảm 1 giờ/ngày (tối thiểu 7h = 1 công)");
                }
            }
        } else {
            info.put("youngChild", false);
            info.put("continuousShift", false);
            info.put("effectiveDayHours", schedule.totalHours());
        }
        return info;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getConfigAdminView() {
        return configView(
                configToMap(requireConfig(AttendanceShiftSeason.SUMMER)),
                configToMap(requireConfig(AttendanceShiftSeason.WINTER)),
                true);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getEmployeeConfigAdminView(Long employeeId) {
        employeeService.requireEmployeeEntity(employeeId);
        EmployeeAttendanceShiftConfig summer = employeeConfigRepository
                .findByEmployee_IdAndSeason(employeeId, AttendanceShiftSeason.SUMMER)
                .orElse(null);
        EmployeeAttendanceShiftConfig winter = employeeConfigRepository
                .findByEmployee_IdAndSeason(employeeId, AttendanceShiftSeason.WINTER)
                .orElse(null);
        Map<String, Object> out = configView(
                summer != null ? configToMap(summer) : configToMap(requireConfig(AttendanceShiftSeason.SUMMER)),
                winter != null ? configToMap(winter) : configToMap(requireConfig(AttendanceShiftSeason.WINTER)),
                summer == null && winter == null);
        out.put("employeeId", employeeId);
        out.put("summerInherited", summer == null);
        out.put("winterInherited", winter == null);
        return out;
    }

    private static Map<String, Object> configView(
            Map<String, Object> summer, Map<String, Object> winter, boolean inherited) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("summer", summer);
        out.put("winter", winter);
        out.put("periodLabels", Map.of(
                "summer", "15/4 – 15/10",
                "winter", "16/10 – 14/4"));
        out.put("inherited", inherited);
        return out;
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> updateSeasonConfig(AttendanceShiftSeason season, AttendanceShiftConfigUpdateRequest req) {
        validateConfig(req);
        AttendanceShiftConfig cfg = configRepository.findById(season)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cấu hình ca " + season));
        applyRequest(cfg, req);
        configRepository.save(cfg);
        reloadCache();
        return getConfigAdminView();
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> updateEmployeeSeasonConfig(
            Long employeeId, AttendanceShiftSeason season, AttendanceShiftConfigUpdateRequest req) {
        validateConfig(req);
        Employee employee = employeeService.requireEmployeeEntity(employeeId);
        EmployeeAttendanceShiftConfig cfg = employeeConfigRepository
                .findByEmployee_IdAndSeason(employeeId, season)
                .orElseGet(() -> EmployeeAttendanceShiftConfig.builder()
                        .employee(employee)
                        .season(season)
                        .build());
        applyRequest(cfg, req);
        employeeConfigRepository.save(cfg);
        return getEmployeeConfigAdminView(employeeId);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> applySeasonConfigToAll(
            AttendanceShiftSeason season, AttendanceShiftConfigUpdateRequest req) {
        validateConfig(req);
        int updated = 0;
        for (Employee employee : employeeRepository.findAll()) {
            if (employee.getStatus() == EmployeeStatus.TERMINATED) {
                continue;
            }
            EmployeeAttendanceShiftConfig cfg = employeeConfigRepository
                    .findByEmployee_IdAndSeason(employee.getId(), season)
                    .orElseGet(() -> EmployeeAttendanceShiftConfig.builder()
                            .employee(employee)
                            .season(season)
                            .build());
            applyRequest(cfg, req);
            employeeConfigRepository.save(cfg);
            updated++;
        }
        return Map.of("updatedEmployees", updated, "season", season.name());
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> setEmployeeContinuousShift(
            Long employeeId, int year, int month, Boolean continuousShift, List<LocalDate> dates) {
        employeeService.requireEmployeeEntity(employeeId);
        if (month < 1 || month > 12) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Tháng không hợp lệ");
        }
        List<LocalDate> saved;
        if (dates != null) {
            saved = continuousShiftService.replaceMonthDates(employeeId, year, month, dates);
        } else if (continuousShift != null) {
            continuousShiftService.setContinuousShiftMonth(employeeId, year, month, continuousShift);
            saved = continuousShiftService.datesInMonth(employeeId, year, month);
        } else {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần gửi danh sách ngày hoặc cờ continuousShift");
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("employeeId", employeeId);
        result.put("periodYear", year);
        result.put("periodMonth", month);
        result.put("dates", saved.stream().map(LocalDate::toString).toList());
        result.put("continuousShift", !saved.isEmpty());
        result.put("dayCount", saved.size());
        return result;
    }

    @PreAuthorize("isAuthenticated()")
    @Transactional(readOnly = true)
    public Map<String, Object> getEmployeeContinuousShiftDays(Long employeeId, int year, int month) {
        employeeService.requireEmployeeEntity(employeeId);
        if (month < 1 || month > 12) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Tháng không hợp lệ");
        }
        List<LocalDate> dates = continuousShiftService.datesInMonth(employeeId, year, month);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("employeeId", employeeId);
        result.put("periodYear", year);
        result.put("periodMonth", month);
        result.put("dates", dates.stream().map(LocalDate::toString).toList());
        result.put("continuousShift", !dates.isEmpty());
        result.put("dayCount", dates.size());
        return result;
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> setEmployeeYoungChild(
            Long employeeId, int year, int month, boolean youngChild) {
        employeeService.requireEmployeeEntity(employeeId);
        if (month < 1 || month > 12) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Tháng không hợp lệ");
        }
        youngChildHoursService.setYoungChildMonth(employeeId, year, month, youngChild);
        return Map.of(
                "employeeId", employeeId,
                "periodYear", year,
                "periodMonth", month,
                "youngChild", youngChild);
    }

    private AttendanceShiftConfig requireConfig(AttendanceShiftSeason season) {
        AttendanceShiftConfig cfg = cached.get(season);
        if (cfg != null) {
            return cfg;
        }
        reloadCache();
        cfg = cached.get(season);
        if (cfg == null) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Thiếu cấu hình ca " + season);
        }
        return cfg;
    }

    private void reloadCache() {
        Map<AttendanceShiftSeason, AttendanceShiftConfig> next = new EnumMap<>(AttendanceShiftSeason.class);
        for (AttendanceShiftConfig c : configRepository.findAll()) {
            next.put(c.getSeason(), c);
        }
        cached = next;
    }

    private static AttendanceShiftSchedule toSchedule(AttendanceShiftConfig cfg, boolean summer) {
        LocalTime contStart = cfg.getContinuousStart() != null ? cfg.getContinuousStart() : cfg.getMorningStart();
        LocalTime contEnd = cfg.getContinuousEnd() != null ? cfg.getContinuousEnd() : cfg.getAfternoonEnd();
        return new AttendanceShiftSchedule(
                cfg.getMorningStart(),
                cfg.getMorningEnd(),
                cfg.getAfternoonStart(),
                cfg.getAfternoonEnd(),
                contStart,
                contEnd,
                cfg.getMorningUnits(),
                cfg.getAfternoonUnits(),
                summer,
                hoursBetween(cfg.getMorningStart(), cfg.getMorningEnd()),
                hoursBetween(cfg.getAfternoonStart(), cfg.getAfternoonEnd()),
                toPunchWindows(cfg));
    }

    private static AttendanceShiftSchedule toSchedule(EmployeeAttendanceShiftConfig cfg, boolean summer) {
        return new AttendanceShiftSchedule(
                cfg.getMorningStart(),
                cfg.getMorningEnd(),
                cfg.getAfternoonStart(),
                cfg.getAfternoonEnd(),
                cfg.getContinuousStart(),
                cfg.getContinuousEnd(),
                cfg.getMorningUnits(),
                cfg.getAfternoonUnits(),
                summer,
                hoursBetween(cfg.getMorningStart(), cfg.getMorningEnd()),
                hoursBetween(cfg.getAfternoonStart(), cfg.getAfternoonEnd()),
                new AttendancePunchWindows(
                        cfg.getMorningInBeforeMin(),
                        cfg.getMorningInAfterMin(),
                        cfg.getMorningOutBeforeMin(),
                        cfg.getMorningOutAfterMin(),
                        cfg.getAfternoonInBeforeMin(),
                        cfg.getAfternoonInAfterMin(),
                        cfg.getAfternoonOutBeforeMin(),
                        cfg.getAfternoonOutAfterMin()));
    }

    private static AttendancePunchWindows toPunchWindows(AttendanceShiftConfig cfg) {
        return new AttendancePunchWindows(
                cfg.getMorningInBeforeMin(),
                cfg.getMorningInAfterMin(),
                cfg.getMorningOutBeforeMin(),
                cfg.getMorningOutAfterMin(),
                cfg.getAfternoonInBeforeMin(),
                cfg.getAfternoonInAfterMin(),
                cfg.getAfternoonOutBeforeMin(),
                cfg.getAfternoonOutAfterMin());
    }

    private static double hoursBetween(LocalTime start, LocalTime end) {
        return Duration.between(start, end).toMinutes() / 60.0;
    }

    private static Map<String, Object> configToMap(AttendanceShiftConfig cfg) {
        Map<String, Object> m = new LinkedHashMap<>();
        LocalTime contStart = cfg.getContinuousStart() != null ? cfg.getContinuousStart() : cfg.getMorningStart();
        LocalTime contEnd = cfg.getContinuousEnd() != null ? cfg.getContinuousEnd() : cfg.getAfternoonEnd();
        m.put("morningStart", cfg.getMorningStart().toString());
        m.put("morningEnd", cfg.getMorningEnd().toString());
        m.put("afternoonStart", cfg.getAfternoonStart().toString());
        m.put("afternoonEnd", cfg.getAfternoonEnd().toString());
        m.put("continuousStart", contStart.toString());
        m.put("continuousEnd", contEnd.toString());
        m.put("morningUnits", cfg.getMorningUnits());
        m.put("afternoonUnits", cfg.getAfternoonUnits());
        m.put("morningUnitsLabel", AttendanceShiftSchedule.formatUnitsLabel(cfg.getMorningUnits()));
        m.put("afternoonUnitsLabel", AttendanceShiftSchedule.formatUnitsLabel(cfg.getAfternoonUnits()));
        m.put("morningHours", hoursBetween(cfg.getMorningStart(), cfg.getMorningEnd()));
        m.put("afternoonHours", hoursBetween(cfg.getAfternoonStart(), cfg.getAfternoonEnd()));
        m.put("continuousHours", hoursBetween(contStart, contEnd));
        m.put("punchWindows", punchWindowsToMap(cfg));
        return m;
    }

    private static Map<String, Object> configToMap(EmployeeAttendanceShiftConfig cfg) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("morningStart", cfg.getMorningStart().toString());
        m.put("morningEnd", cfg.getMorningEnd().toString());
        m.put("afternoonStart", cfg.getAfternoonStart().toString());
        m.put("afternoonEnd", cfg.getAfternoonEnd().toString());
        m.put("continuousStart", cfg.getContinuousStart().toString());
        m.put("continuousEnd", cfg.getContinuousEnd().toString());
        m.put("morningUnits", cfg.getMorningUnits());
        m.put("afternoonUnits", cfg.getAfternoonUnits());
        m.put("morningUnitsLabel", AttendanceShiftSchedule.formatUnitsLabel(cfg.getMorningUnits()));
        m.put("afternoonUnitsLabel", AttendanceShiftSchedule.formatUnitsLabel(cfg.getAfternoonUnits()));
        m.put("morningHours", hoursBetween(cfg.getMorningStart(), cfg.getMorningEnd()));
        m.put("afternoonHours", hoursBetween(cfg.getAfternoonStart(), cfg.getAfternoonEnd()));
        m.put("continuousHours", hoursBetween(cfg.getContinuousStart(), cfg.getContinuousEnd()));
        Map<String, Object> p = new LinkedHashMap<>();
        p.put("morningInBeforeMin", cfg.getMorningInBeforeMin());
        p.put("morningInAfterMin", cfg.getMorningInAfterMin());
        p.put("morningOutBeforeMin", cfg.getMorningOutBeforeMin());
        p.put("morningOutAfterMin", cfg.getMorningOutAfterMin());
        p.put("afternoonInBeforeMin", cfg.getAfternoonInBeforeMin());
        p.put("afternoonInAfterMin", cfg.getAfternoonInAfterMin());
        p.put("afternoonOutBeforeMin", cfg.getAfternoonOutBeforeMin());
        p.put("afternoonOutAfterMin", cfg.getAfternoonOutAfterMin());
        m.put("punchWindows", p);
        return m;
    }

    private static Map<String, Object> punchWindowsToMap(AttendanceShiftConfig cfg) {
        Map<String, Object> p = new LinkedHashMap<>();
        p.put("morningInBeforeMin", cfg.getMorningInBeforeMin());
        p.put("morningInAfterMin", cfg.getMorningInAfterMin());
        p.put("morningOutBeforeMin", cfg.getMorningOutBeforeMin());
        p.put("morningOutAfterMin", cfg.getMorningOutAfterMin());
        p.put("afternoonInBeforeMin", cfg.getAfternoonInBeforeMin());
        p.put("afternoonInAfterMin", cfg.getAfternoonInAfterMin());
        p.put("afternoonOutBeforeMin", cfg.getAfternoonOutBeforeMin());
        p.put("afternoonOutAfterMin", cfg.getAfternoonOutAfterMin());
        return p;
    }

    /** Ca thông tầm / khung ngày: tối thiểu 8 giờ từ giờ vào đầu ngày → giờ ra cuối ngày. */
    private static final double CONTINUOUS_MIN_HOURS = 8.0;

    private static void validateConfig(AttendanceShiftConfigUpdateRequest req) {
        if (!req.getMorningStart().isBefore(req.getMorningEnd())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Giờ bắt đầu ca sáng phải trước giờ kết thúc ca sáng");
        }
        if (!req.getAfternoonStart().isBefore(req.getAfternoonEnd())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Giờ bắt đầu ca chiều phải trước giờ kết thúc ca chiều");
        }
        if (!req.getContinuousStart().isBefore(req.getContinuousEnd())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Giờ vào ca thông tầm phải trước giờ ra");
        }
        double continuousHours = Duration.between(req.getContinuousStart(), req.getContinuousEnd()).toMinutes() / 60.0;
        if (continuousHours < CONTINUOUS_MIN_HOURS) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Ca thông tầm (vào → ra) phải tối thiểu 8 giờ");
        }
        if (req.getMorningUnits().compareTo(BigDecimal.ZERO) <= 0
                || req.getAfternoonUnits().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn vị công phải lớn hơn 0");
        }
        validatePunchWindowMinutes(req.getMorningInBeforeMin(), req.getMorningInAfterMin(), "vào ca sáng");
        validatePunchWindowMinutes(req.getMorningOutBeforeMin(), req.getMorningOutAfterMin(), "ra ca sáng");
        validatePunchWindowMinutes(req.getAfternoonInBeforeMin(), req.getAfternoonInAfterMin(), "vào ca chiều");
        validatePunchWindowMinutes(req.getAfternoonOutBeforeMin(), req.getAfternoonOutAfterMin(), "ra ca chiều");
    }

    private static void validatePunchWindowMinutes(int beforeMin, int afterMin, String label) {
        if (beforeMin < 0 || afterMin < 0 || beforeMin > 12 * 60 || afterMin > 12 * 60) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cửa sổ lấy giờ " + label + " không hợp lệ (0–720 phút)");
        }
    }

    private static void applyRequest(AttendanceShiftConfig cfg, AttendanceShiftConfigUpdateRequest req) {
        cfg.setMorningStart(req.getMorningStart());
        cfg.setMorningEnd(req.getMorningEnd());
        cfg.setAfternoonStart(req.getAfternoonStart());
        cfg.setAfternoonEnd(req.getAfternoonEnd());
        cfg.setContinuousStart(req.getContinuousStart());
        cfg.setContinuousEnd(req.getContinuousEnd());
        cfg.setMorningUnits(req.getMorningUnits());
        cfg.setAfternoonUnits(req.getAfternoonUnits());
        cfg.setMorningInBeforeMin(req.getMorningInBeforeMin());
        cfg.setMorningInAfterMin(req.getMorningInAfterMin());
        cfg.setMorningOutBeforeMin(req.getMorningOutBeforeMin());
        cfg.setMorningOutAfterMin(req.getMorningOutAfterMin());
        cfg.setAfternoonInBeforeMin(req.getAfternoonInBeforeMin());
        cfg.setAfternoonInAfterMin(req.getAfternoonInAfterMin());
        cfg.setAfternoonOutBeforeMin(req.getAfternoonOutBeforeMin());
        cfg.setAfternoonOutAfterMin(req.getAfternoonOutAfterMin());
    }

    private static void applyRequest(EmployeeAttendanceShiftConfig cfg, AttendanceShiftConfigUpdateRequest req) {
        cfg.setMorningStart(req.getMorningStart());
        cfg.setMorningEnd(req.getMorningEnd());
        cfg.setAfternoonStart(req.getAfternoonStart());
        cfg.setAfternoonEnd(req.getAfternoonEnd());
        cfg.setContinuousStart(req.getContinuousStart());
        cfg.setContinuousEnd(req.getContinuousEnd());
        cfg.setMorningUnits(req.getMorningUnits());
        cfg.setAfternoonUnits(req.getAfternoonUnits());
        cfg.setMorningInBeforeMin(req.getMorningInBeforeMin());
        cfg.setMorningInAfterMin(req.getMorningInAfterMin());
        cfg.setMorningOutBeforeMin(req.getMorningOutBeforeMin());
        cfg.setMorningOutAfterMin(req.getMorningOutAfterMin());
        cfg.setAfternoonInBeforeMin(req.getAfternoonInBeforeMin());
        cfg.setAfternoonInAfterMin(req.getAfternoonInAfterMin());
        cfg.setAfternoonOutBeforeMin(req.getAfternoonOutBeforeMin());
        cfg.setAfternoonOutAfterMin(req.getAfternoonOutAfterMin());
    }
}
