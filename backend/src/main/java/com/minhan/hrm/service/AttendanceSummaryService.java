package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceDayProcessor;
import com.minhan.hrm.attendance.AttendancePenaltyCalculator;
import com.minhan.hrm.attendance.ForgotPenaltySettings;
import com.minhan.hrm.attendance.LatePenaltySettings;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.AttendanceWorkRequestRepository;
import com.minhan.hrm.repository.EmployeeSalaryProfileRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.SeminarProposalRequestRepository;
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

    private static final BigDecimal QUANG_TRUNG_DOCTOR_ALLOWANCE = new BigDecimal("100000");
    private static final BigDecimal QUANG_TRUNG_EMPLOYEE_ALLOWANCE = new BigDecimal("50000");

    private final AttendanceRecordRepository attendanceRecordRepository;
    private final AttendanceWorkRequestRepository workRequestRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeService employeeService;
    private final AttendanceShiftScheduleService shiftScheduleService;
    private final ForgotPenaltyConfigService forgotPenaltyConfigService;
    private final LatePenaltyConfigService latePenaltyConfigService;
    private final AttendanceDayProcessor dayProcessor;
    private final DutyShiftService dutyShiftService;
    private final SeminarProposalRequestRepository seminarProposalRepository;
    private final EmployeeSalaryProfileRepository salaryProfileRepository;
    private final YoungChildHoursService youngChildHoursService;

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
        if (current.getRole() != UserRole.ADMIN
                && current.getRole() != UserRole.HR
                && !EmployeeService.isHr2Role(current)) {
            throw new com.minhan.hrm.exception.ApiException(
                    org.springframework.http.HttpStatus.FORBIDDEN, "Chỉ ADMIN/HR/HCNS2 xem bảng công tổng hợp");
        }
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        List<Employee> employees = employeeRepository.findAll().stream()
                .filter(e -> e.getStatus() != null && e.getStatus() != EmployeeStatus.TERMINATED)
                .filter(e -> departmentId == null
                        || (e.getDepartment() != null && e.getDepartment().getId().equals(departmentId)))
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
                    "department", emp.getDepartment() != null ? emp.getDepartment().getName() : "",
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
     * Dữ liệu báo cáo công cả tháng cho toàn bộ nhân viên đang làm việc
     * (chính thức + thử việc + thực tập + nghỉ phép tạm; tùy chọn lọc phòng ban).
     * Mỗi phần tử gồm summary đầy đủ + mã NV, phòng ban, chức vụ và danh sách công theo ngày.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> monthReport(int year, int month, Long departmentId) {
        UserAccount current = employeeService.currentUser();
        Long effectiveDepartmentId;
        if (EmployeeService.isHr2Role(current)
                || current.getRole() == UserRole.ADMIN
                || current.getRole() == UserRole.HR
                || current.getRole() == UserRole.HEAD_NURSING) {
            effectiveDepartmentId = departmentId;
        } else if (EmployeeService.isHeadRole(current)) {
            // Luôn khóa theo khoa lấy từ hồ sơ liên kết; không tin departmentId do client gửi lên.
            effectiveDepartmentId = employeeService.resolveHeadDepartmentScope(current);
        } else {
            throw new com.minhan.hrm.exception.ApiException(
                    org.springframework.http.HttpStatus.FORBIDDEN,
                    "Chỉ ADMIN/HR hoặc Trưởng khoa/Trưởng phòng Điều dưỡng được xuất báo cáo công");
        }
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        String scopedWorkUnit = EmployeeService.isHeadRole(current) && !EmployeeService.isHr2Role(current)
                ? employeeService.resolveHeadWorkUnitScope(current)
                : null;
        boolean nursingBlockOnly = current.getRole() == UserRole.HEAD_NURSING;
        // Đầy đủ NV đang làm: chính thức + thử việc + thực tập + nghỉ phép tạm (không gồm đã nghỉ việc).
        List<Employee> employees = employeeRepository.findAll().stream()
                .filter(e -> e.getStatus() != null && e.getStatus() != EmployeeStatus.TERMINATED)
                .filter(e -> effectiveDepartmentId == null
                        || (e.getDepartment() != null
                        && effectiveDepartmentId.equals(e.getDepartment().getId())))
                .filter(e -> scopedWorkUnit == null || employeeService.matchesWorkUnit(e, scopedWorkUnit))
                .filter(e -> !nursingBlockOnly || NursingBlockClassifier.matches(e))
                .sorted(Comparator
                        .comparing((Employee e) -> e.getDepartment() != null ? e.getDepartment().getName() : "",
                                String.CASE_INSENSITIVE_ORDER)
                        .thenComparing(Employee::getFullName, String.CASE_INSENSITIVE_ORDER))
                .toList();
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Employee emp : employees) {
            List<AttendanceRecord> records = attendanceRecordRepository
                    .findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to);
            Map<String, Object> summary = buildSummary(emp, records, from, to);
            summary.put("employeeCode", emp.getEmployeeCode() != null ? emp.getEmployeeCode() : "");
            summary.put("departmentId", emp.getDepartment() != null ? emp.getDepartment().getId() : null);
            summary.put("department", emp.getDepartment() != null ? emp.getDepartment().getName() : "");
            summary.put("position", emp.getPosition() != null ? emp.getPosition().getTitle() : "");
            summary.put("phone", emp.getPhone() != null ? emp.getPhone() : "");
            summary.put("employeeStatus", emp.getStatus() != null ? emp.getStatus().name() : "");
            Set<LocalDate> youngChildDates = youngChildHoursService.datesForEmployee(emp.getId(), from, to);
            summary.put("days", records.stream().map(r -> dayDetail(r, youngChildDates)).toList());
            summary.put("dutyDays", dutyShiftService.reportEntries(
                    emp, dutyShiftService.findEntriesForEmployee(emp.getId(), from, to)));
            rows.add(summary);
        }
        return rows;
    }

    /**
     * Ma trận công theo ngày (dạng bảng chấm công Excel) để xem trên UI.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> monthMatrix(int year, int month, Long departmentId) {
        YearMonth ym = YearMonth.of(year, month);
        List<Map<String, Object>> rows = monthReport(year, month, departmentId);
        UserAccount current = employeeService.currentUser();
        Long effectiveDepartmentId = EmployeeService.isHeadRole(current)
                ? employeeService.resolveHeadDepartmentScope(current)
                : departmentId;
        String departmentName = "Toàn bệnh viện";
        if (effectiveDepartmentId != null && !rows.isEmpty()) {
            Object name = rows.get(0).get("department");
            if (name != null && !String.valueOf(name).isBlank()) {
                departmentName = String.valueOf(name);
            }
        } else if (effectiveDepartmentId != null) {
            departmentName = "Theo khoa đã chọn";
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("year", year);
        out.put("month", month);
        out.put("daysInMonth", ym.lengthOfMonth());
        out.put("departmentId", effectiveDepartmentId);
        out.put("departmentName", departmentName);
        out.put("rows", rows);
        return out;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> employeeMonthDetail(Long employeeId, int year, int month) {
        Map<String, Object> summary = employeeMonthSummary(employeeId, year, month);
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        YearMonth ym = YearMonth.of(year, month);
        List<AttendanceRecord> records = attendanceRecordRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
                emp, ym.atDay(1), ym.atEndOfMonth());
        Set<LocalDate> youngChildDates = youngChildHoursService.datesForEmployee(
                employeeId, ym.atDay(1), ym.atEndOfMonth());
        List<Map<String, Object>> days = records.stream().map(r -> dayDetail(r, youngChildDates)).toList();
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
        BigDecimal leaveUnits = BigDecimal.ZERO;
        int lateMinutes = 0;
        for (AttendanceRecord r : records) {
            BigDecimal dayUnits = nzUnits(r.getMorningWorkUnits())
                    .add(nzUnits(r.getAfternoonWorkUnits()))
                    .add(nzUnits(r.getOvertimeWorkUnits()));
            totalUnits = totalUnits.add(dayUnits);
            if ("LEAVE".equals(r.getStatus())) {
                leaveUnits = leaveUnits.add(dayUnits);
            }
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
        SeminarSupportTotals seminarSupport = computeSeminarSupport(emp.getId(), from, to);
        QuangTrungAllowanceTotals quangTrungAllowance =
                computeQuangTrungAllowance(emp, records);
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("employeeId", emp.getId());
        summary.put("fullName", emp.getFullName());
        summary.put("periodYear", from.getYear());
        summary.put("periodMonth", from.getMonthValue());
        summary.put("attendanceWorkUnits", totalUnits);
        summary.put("clockedWorkUnits", totalUnits.subtract(leaveUnits).max(BigDecimal.ZERO));
        summary.put("leaveWorkUnits", leaveUnits);
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
        summary.put("seminarSupportTotal", seminarSupport.amount());
        summary.put("seminarSupportCount", seminarSupport.count());
        summary.put("quangTrungAllowance", quangTrungAllowance.amount());
        summary.put("quangTrungAllowanceCount", quangTrungAllowance.count());
        summary.put("quangTrungAllowanceRate", quangTrungAllowance.rate());
        return summary;
    }

    private QuangTrungAllowanceTotals computeQuangTrungAllowance(
            Employee employee, List<AttendanceRecord> records) {
        int count = (int) records.stream()
                .map(AttendanceRecord::getNote)
                .filter(Objects::nonNull)
                .filter(note -> note.contains(AttendanceService.QUANG_TRUNG_NOTE_MARKER))
                .count();
        boolean doctor = salaryProfileRepository.findByEmployee(employee)
                .map(profile -> profile.getSalaryCategory() == SalaryCategory.DOCTOR)
                .orElse(false);
        BigDecimal rate = doctor
                ? QUANG_TRUNG_DOCTOR_ALLOWANCE
                : QUANG_TRUNG_EMPLOYEE_ALLOWANCE;
        return new QuangTrungAllowanceTotals(
                count, rate, rate.multiply(BigDecimal.valueOf(count)));
    }

    private record QuangTrungAllowanceTotals(
            int count, BigDecimal rate, BigDecimal amount) {}

    private SeminarSupportTotals computeSeminarSupport(Long employeeId, LocalDate from, LocalDate to) {
        List<SeminarProposalRequest> rows =
                seminarProposalRepository.findApprovedWithSupportInPeriod(employeeId, from, to);
        BigDecimal total = BigDecimal.ZERO;
        for (SeminarProposalRequest row : rows) {
            total = total.add(parseMoneyAmount(row.getSupportAmount()));
        }
        return new SeminarSupportTotals(rows.size(), total);
    }

    private static BigDecimal parseMoneyAmount(String raw) {
        if (raw == null || raw.isBlank()) {
            return BigDecimal.ZERO;
        }
        String t = raw.trim().replaceAll("[^0-9,.]", "");
        if (t.isBlank()) {
            return BigDecimal.ZERO;
        }
        int lastDot = t.lastIndexOf('.');
        int lastComma = t.lastIndexOf(',');
        if (lastDot >= 0 && lastComma >= 0) {
            if (lastDot > lastComma) {
                t = t.replace(",", "");
            } else {
                t = t.replace(".", "").replace(',', '.');
            }
        } else if (lastDot >= 0 && t.indexOf('.') != lastDot) {
            t = t.replace(".", "");
        } else if (lastComma >= 0 && t.indexOf(',') != lastComma) {
            t = t.replace(",", "");
        } else if (lastComma >= 0) {
            t = t.replace(',', '.');
        }
        try {
            return new BigDecimal(t);
        } catch (NumberFormatException ex) {
            return BigDecimal.ZERO;
        }
    }

    private record SeminarSupportTotals(int count, BigDecimal amount) {}

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
            if ("LEAVE".equals(r.getStatus())
                    || "UNPAID_LEAVE".equals(r.getStatus())
                    || "BUSINESS_TRIP".equals(r.getStatus())
                    || "SEMINAR".equals(r.getStatus())) {
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

    private Map<String, Object> dayDetail(AttendanceRecord r, Set<LocalDate> youngChildDates) {
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
        m.put("quangTrung", note.contains(AttendanceService.QUANG_TRUNG_NOTE_MARKER));
        m.put("deployment", note.contains("Điều động làm thêm") || note.contains("Điều động trong ca"));
        m.put("youngChild", youngChildDates.contains(r.getWorkDate()));
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
        m.put("originalMorningIn", timeStr(r.getOriginalMorningIn()));
        m.put("originalMorningOut", timeStr(r.getOriginalMorningOut()));
        m.put("originalAfternoonIn", timeStr(r.getOriginalAfternoonIn()));
        m.put("originalAfternoonOut", timeStr(r.getOriginalAfternoonOut()));
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
        if (EmployeeService.isHr2Role(current)) {
            return;
        }
        employeeService.assertCanAccessEmployee(target);
    }
}
