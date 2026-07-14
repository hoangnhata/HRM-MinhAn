package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceDayProcessor;
import com.minhan.hrm.attendance.AttendancePenaltyCalculator;
import com.minhan.hrm.attendance.ForgotPenaltySettings;
import com.minhan.hrm.attendance.LatePenaltySettings;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.AttendanceWorkRequestRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;

@Service
@RequiredArgsConstructor
public class AttendanceSummaryService {

    private final AttendanceRecordRepository attendanceRecordRepository;
    private final AttendanceWorkRequestRepository workRequestRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeService employeeService;
    private final AttendanceShiftScheduleService shiftScheduleService;
    private final ForgotPenaltyConfigService forgotPenaltyConfigService;
    private final LatePenaltyConfigService latePenaltyConfigService;
    private final AttendanceDayProcessor dayProcessor;
    private final DutyShiftService dutyShiftService;

    @Transactional(readOnly = true)
    public Map<String, Object> employeeMonthSummary(Long employeeId, int year, int month) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanView(emp);
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        List<AttendanceRecord> records = attendanceRecordRepository
                .findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to);
        return buildSummary(emp, records, from, to);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> departmentMonthSummary(int year, int month, Long departmentId) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() != UserRole.ADMIN && current.getRole() != UserRole.HR) {
            throw new com.minhan.hrm.exception.ApiException(
                    org.springframework.http.HttpStatus.FORBIDDEN, "Chỉ ADMIN/HR xem bảng công tổng hợp");
        }
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        List<Employee> employees = employeeRepository.findAll().stream()
                .filter(e -> e.getStatus() == EmployeeStatus.ACTIVE)
                .filter(e -> departmentId == null || e.getDepartment().getId().equals(departmentId))
                .toList();
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Employee emp : employees) {
            List<AttendanceRecord> records = attendanceRecordRepository
                    .findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to);
            Map<String, Object> s = buildSummary(emp, records, from, to);
            rows.add(Map.of(
                    "employeeId", emp.getId(),
                    "employeeCode", emp.getEmployeeCode() != null ? emp.getEmployeeCode() : "",
                    "fullName", emp.getFullName(),
                    "department", emp.getDepartment().getName(),
                    "totalWorkUnits", s.get("totalWorkUnits"),
                    "latePenalty", s.get("latePenalty"),
                    "forgotPenalty", s.get("forgotPenalty"),
                    "lateMinutesTotal", s.get("lateMinutesTotal"),
                    "forgotFineCount", s.get("forgotFineCount"),
                    "requiresDiscipline", s.get("requiresDiscipline")));
        }
        rows.sort(Comparator.comparing(r -> (String) r.get("fullName")));
        return rows;
    }

    /**
     * Dữ liệu báo cáo công cả tháng cho toàn bộ nhân viên đang làm việc (tùy chọn lọc phòng ban).
     * Mỗi phần tử gồm summary đầy đủ + mã NV, phòng ban, chức vụ và danh sách công theo ngày.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> monthReport(int year, int month, Long departmentId) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() != UserRole.ADMIN && current.getRole() != UserRole.HR) {
            throw new com.minhan.hrm.exception.ApiException(
                    org.springframework.http.HttpStatus.FORBIDDEN, "Chỉ ADMIN/HR xuất báo cáo công");
        }
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        List<Employee> employees = employeeRepository.findAll().stream()
                .filter(e -> e.getStatus() == EmployeeStatus.ACTIVE || e.getStatus() == EmployeeStatus.ON_LEAVE)
                .filter(e -> departmentId == null || e.getDepartment().getId().equals(departmentId))
                .sorted(Comparator
                        .comparing((Employee e) -> e.getDepartment().getName(), String.CASE_INSENSITIVE_ORDER)
                        .thenComparing(Employee::getFullName, String.CASE_INSENSITIVE_ORDER))
                .toList();
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Employee emp : employees) {
            List<AttendanceRecord> records = attendanceRecordRepository
                    .findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to);
            Map<String, Object> summary = buildSummary(emp, records, from, to);
            summary.put("employeeCode", emp.getEmployeeCode() != null ? emp.getEmployeeCode() : "");
            summary.put("department", emp.getDepartment().getName());
            summary.put("position", emp.getPosition() != null ? emp.getPosition().getTitle() : "");
            summary.put("days", records.stream().map(this::dayDetail).toList());
            summary.put("dutyDays", dutyShiftService.reportEntries(
                    emp, dutyShiftService.findEntriesForEmployee(emp.getId(), from, to)));
            rows.add(summary);
        }
        return rows;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> employeeMonthDetail(Long employeeId, int year, int month) {
        Map<String, Object> summary = employeeMonthSummary(employeeId, year, month);
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        YearMonth ym = YearMonth.of(year, month);
        List<AttendanceRecord> records = attendanceRecordRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
                emp, ym.atDay(1), ym.atEndOfMonth());
        List<Map<String, Object>> days = records.stream().map(this::dayDetail).toList();
        List<AttendanceWorkRequest> requests = workRequestRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateDescCreatedAtDesc(
                emp, ym.atDay(1), ym.atEndOfMonth());
        summary.put("days", days);
        summary.put("requests", requests.stream().map(this::requestMap).toList());
        Map<String, Object> shiftRules = new LinkedHashMap<>(shiftScheduleService.infoForDate(ym.atDay(15), employeeId));
        shiftRules.put("lateTiers", AttendancePenaltyCalculator.latePenaltyTiers(latePenaltyConfigService.currentSettings()));
        shiftRules.put("forgotTiers", forgotPenaltyConfigService.displayTiers(forgotPenaltyConfigService.currentSettings()));
        summary.put("shiftRules", shiftRules);
        return summary;
    }

    private Map<String, Object> buildSummary(
            Employee emp, List<AttendanceRecord> records, LocalDate from, LocalDate to) {
        BigDecimal totalUnits = BigDecimal.ZERO;
        int lateMinutes = 0;
        for (AttendanceRecord r : records) {
            totalUnits = totalUnits
                    .add(nzUnits(r.getMorningWorkUnits()))
                    .add(nzUnits(r.getAfternoonWorkUnits()))
                    .add(nzUnits(r.getOvertimeWorkUnits()));
            if (!r.isLateMinutesExempt()) {
                lateMinutes += r.getLateMinutes();
            }
        }
        LatePenaltySettings lateSettings = latePenaltyConfigService.currentSettings();
        AttendancePenaltyCalculator.LatePenaltyResult late =
                AttendancePenaltyCalculator.latePenaltyForMonth(lateMinutes, lateSettings);
        ForgotPenaltySettings forgotSettings = forgotPenaltyConfigService.currentSettings();
        int forgotFineCount = countForgotFinedRequests(emp.getId(), from, to);
        BigDecimal forgotPenalty = AttendancePenaltyCalculator.totalForgotPenalty(forgotFineCount, forgotSettings);
        Map<String, Object> dutyTotals = dutyShiftService.rollup(
                emp, dutyShiftService.findEntriesForEmployee(emp.getId(), from, to));
        int dutyShiftCount = ((Number) dutyTotals.get("dutyShiftCount")).intValue();
        MealAllowanceTotals meal = computeMealAllowance(records, dutyShiftCount);
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("employeeId", emp.getId());
        summary.put("fullName", emp.getFullName());
        summary.put("periodYear", from.getYear());
        summary.put("periodMonth", from.getMonthValue());
        summary.put("attendanceWorkUnits", totalUnits);
        summary.put("totalWorkUnits", totalUnits.add((BigDecimal) dutyTotals.get("dutyWorkUnitsTotal")));
        summary.put("lateMinutesTotal", lateMinutes);
        summary.put("latePenalty", late.amount());
        summary.put("latePenaltyTier", late.tierLabel() != null ? late.tierLabel() : "");
        summary.put("requiresDiscipline", late.requiresDiscipline());
        summary.put("forgotFineCount", forgotFineCount);
        summary.put("forgotPenalty", forgotPenalty);
        summary.put("dutyBonusTotal", dutyTotals.get("dutyBonusTotal"));
        summary.put("dutyPostPayTotal", dutyTotals.get("dutyPostPayTotal"));
        summary.put("dutyWorkUnitsTotal", dutyTotals.get("dutyWorkUnitsTotal"));
        summary.put("dutyShiftCount", dutyTotals.get("dutyShiftCount"));
        summary.put("mealAllowance", meal.amount());
        summary.put("mealAllowanceUnits", meal.totalUnits());
        summary.put("mealAllowancePresentDays", meal.presentDays());
        summary.put("mealAllowanceMorningDays", meal.morningDays());
        summary.put("mealAllowanceDutyUnits", meal.dutyUnits());
        return summary;
    }

    private static final BigDecimal MEAL_ALLOWANCE_PER_UNIT = new BigDecimal("20000");

    private MealAllowanceTotals computeMealAllowance(List<AttendanceRecord> records, int dutyShiftCount) {
        int presentDays = 0;
        int morningDays = 0;
        for (AttendanceRecord r : records) {
            BigDecimal totalUnits = r.getMorningWorkUnits().add(r.getAfternoonWorkUnits());
            boolean hasMorning = hasMorningPunch(r);
            boolean hasAfternoon = hasAfternoonPunch(r);
            // Tính theo công thực tế — tránh trạng thái cũ còn sót sau khi xóa bổ sung QT
            // Ngày nghỉ phép / công tác không tính phụ cấp phần ăn tại viện
            if ("LEAVE".equals(r.getStatus()) || "BUSINESS_TRIP".equals(r.getStatus())) {
                continue;
            }
            if (totalUnits.compareTo(new BigDecimal("0.99")) >= 0) {
                presentDays++;
            } else if (hasMorning && !hasAfternoon && totalUnits.compareTo(BigDecimal.ZERO) > 0) {
                morningDays++;
            }
        }
        int dutyUnits = dutyShiftCount * 2;
        int totalUnits = presentDays + morningDays + dutyUnits;
        BigDecimal amount = MEAL_ALLOWANCE_PER_UNIT.multiply(BigDecimal.valueOf(totalUnits));
        return new MealAllowanceTotals(presentDays, morningDays, dutyShiftCount, dutyUnits, totalUnits, amount);
    }

    private static boolean hasMorningPunch(AttendanceRecord r) {
        return r.getMorningCheckIn() != null
                || r.getMorningWorkUnits().compareTo(BigDecimal.ZERO) > 0;
    }

    private static boolean hasAfternoonPunch(AttendanceRecord r) {
        return r.getAfternoonCheckIn() != null
                || r.getAfternoonCheckOut() != null
                || r.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO) > 0;
    }

    private record MealAllowanceTotals(
            int presentDays,
            int morningDays,
            int dutyShiftCount,
            int dutyUnits,
            int totalUnits,
            BigDecimal amount) {}

    private int countForgotFinedRequests(Long employeeId, LocalDate from, LocalDate to) {
        List<AttendanceWorkRequest> approved = workRequestRepository
                .findByEmployeeIdAndWorkDateBetween(employeeId, from, to).stream()
                .filter(r -> r.getRequestType() == AttendanceRequestType.UPDATE)
                .filter(r -> r.getStatus() == AttendanceRequestStatus.APPROVED)
                .sorted(Comparator
                        .comparing(AttendanceWorkRequest::getWorkDate)
                        .thenComparing(AttendanceWorkRequest::getCreatedAt))
                .toList();
        int units = 0;
        for (AttendanceWorkRequest r : approved) {
            units += AttendancePenaltyCalculator.forgotFineUnitsForWorkRequest(r);
        }
        return units;
    }

    private Map<String, Object> dayDetail(AttendanceRecord r) {
        BigDecimal morning = nzUnits(r.getMorningWorkUnits());
        BigDecimal afternoon = nzUnits(r.getAfternoonWorkUnits());
        BigDecimal overtime = nzUnits(r.getOvertimeWorkUnits());
        BigDecimal units = morning.add(afternoon).add(overtime);
        String note = r.getNote() != null ? r.getNote() : "";
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("workDate", r.getWorkDate().toString());
        m.put("status", r.getStatus());
        m.put("morningCheckIn", timeStr(r.getMorningCheckIn()));
        m.put("morningCheckOut", timeStr(r.getMorningCheckOut()));
        m.put("afternoonCheckIn", timeStr(r.getAfternoonCheckIn()));
        m.put("afternoonCheckOut", timeStr(r.getAfternoonCheckOut()));
        m.put("morningWorkUnits", morning);
        m.put("afternoonWorkUnits", afternoon);
        m.put("overtimeWorkUnits", overtime);
        m.put("totalWorkUnits", units);
        m.put("lateMinutes", r.getLateMinutes());
        m.put("lateMinutesExempt", r.isLateMinutesExempt());
        m.put("forgotShifts", r.getForgotShifts() != null ? r.getForgotShifts() : "");
        m.put("checkIn", timeStr(r.getCheckIn()));
        m.put("checkOut", timeStr(r.getCheckOut()));
        m.put("note", note);
        m.put("deployment", note.contains("Điều động làm thêm") || note.contains("Điều động trong ca"));
        m.put("punchTimes", dayProcessor.resolvePunches(r).stream().map(Object::toString).toList());
        return m;
    }

    private static BigDecimal nzUnits(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }

    private Map<String, Object> requestMap(AttendanceWorkRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("requestType", r.getRequestType().name());
        m.put("workDate", r.getWorkDate().toString());
        m.put("shiftScope", r.getShiftScope().name());
        m.put("updateKind", r.getUpdateKind() != null ? r.getUpdateKind().name() : "");
        m.put("reason", r.getReason());
        m.put("requestedStart", timeStr(r.getRequestedStart()));
        m.put("requestedEnd", timeStr(r.getRequestedEnd()));
        m.put("requestedAfternoonStart", timeStr(r.getRequestedAfternoonStart()));
        m.put("requestedAfternoonEnd", timeStr(r.getRequestedAfternoonEnd()));
        m.put("explanationKind", r.getExplanationKind() != null ? r.getExplanationKind().name() : "");
        m.put("explainedTime", timeStr(r.getExplainedTime()));
        m.put("explainedDepartureTime", timeStr(r.getExplainedDepartureTime()));
        m.put("explainedMorningIn", timeStr(r.getExplainedMorningIn()));
        m.put("explainedMorningOut", timeStr(r.getExplainedMorningOut()));
        m.put("explainedAfternoonIn", timeStr(r.getExplainedAfternoonIn()));
        m.put("explainedAfternoonOut", timeStr(r.getExplainedAfternoonOut()));
        m.put("status", r.getStatus().name());
        m.put("hrWaiveForgotFine", r.isHrWaiveForgotFine());
        m.put("createdAt", r.getCreatedAt().toString());
        return m;
    }

    private static String timeStr(java.time.LocalTime t) {
        return t != null ? t.toString() : "";
    }

    private void assertCanView(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() == UserRole.ADMIN || current.getRole() == UserRole.HR) {
            return;
        }
        Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
        if (self != null && self.getId().equals(target.getId())) {
            return;
        }
        if (current.getRole() == UserRole.HEAD_DEPARTMENT || current.getRole() == UserRole.HEAD_NURSING) {
            return;
        }
        throw new com.minhan.hrm.exception.ApiException(
                org.springframework.http.HttpStatus.FORBIDDEN, "Không có quyền xem bảng công");
    }
}
