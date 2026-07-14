package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceDayProcessor;
import com.minhan.hrm.dto.attendance.AttendanceRequest;
import com.minhan.hrm.dto.attendance.CongHoSupplementRequest;
import com.minhan.hrm.dto.attendance.QuangTrungSupplementRequest;
import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.AttendanceShiftScope;
import com.minhan.hrm.entity.AttendanceUpdateKind;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AttendanceService {

    private final AttendanceRecordRepository attendanceRecordRepository;
    private final EmployeeService employeeService;
    private final EmployeeRepository employeeRepository;
    private final NotificationService notificationService;
    private final AttendanceDayProcessor dayProcessor;
    private final ContinuousShiftService continuousShiftService;
    private final HolidayWorkDayService holidayWorkDayService;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listRange(Long employeeId, LocalDate from, LocalDate to) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanViewAttendance(emp);
        return attendanceRecordRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to)
                .stream()
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void notifyEmployeeAboutMonth(Long employeeId, int year, int month) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        notificationService.notifyAttendancePeriod(emp.getUser(), emp, year, month);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> upsert(AttendanceRequest req) {
        Employee emp = employeeService.requireEmployeeEntity(req.getEmployeeId());
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, req.getWorkDate())
                .orElseGet(() -> AttendanceRecord.builder().employee(emp).workDate(req.getWorkDate()).build());
        rec.setCheckIn(req.getCheckIn());
        rec.setCheckOut(req.getCheckOut());
        rec.setNote(req.getNote());
        if (req.getMorningCheckIn() != null) {
            rec.setMorningCheckIn(req.getMorningCheckIn());
        }
        if (req.getMorningCheckOut() != null) {
            rec.setMorningCheckOut(req.getMorningCheckOut());
        }
        if (req.getAfternoonCheckIn() != null) {
            rec.setAfternoonCheckIn(req.getAfternoonCheckIn());
        }
        if (req.getAfternoonCheckOut() != null) {
            rec.setAfternoonCheckOut(req.getAfternoonCheckOut());
        }
        dayProcessor.applyToRecord(rec);
        if (req.getStatus() != null && !req.getStatus().isBlank()) {
            rec.setStatus(req.getStatus());
        }
        rec = attendanceRecordRepository.save(rec);
        return toMap(rec);
    }

    public static final String QUANG_TRUNG_NOTE_MARKER = "Bổ sung công Quang Trung";

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional(readOnly = true)
    public Map<String, Object> getQuangTrungSupplement(Long employeeId, LocalDate workDate) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanViewAttendance(emp);
        AttendanceRecord rec = attendanceRecordRepository.findByEmployeeAndWorkDate(emp, workDate).orElse(null);
        if (rec == null || !isQuangTrungNote(rec.getNote())) {
            return Map.of("exists", false, "workDate", workDate.toString());
        }
        return quangTrungView(rec);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> applyQuangTrungSupplement(Long employeeId, QuangTrungSupplementRequest req) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        validateQuangTrungSupplement(req);
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, req.getWorkDate())
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(emp)
                        .workDate(req.getWorkDate())
                        .status("ABSENT")
                        .build());
        // Ghi đè toàn bộ giờ trong ngày theo loại bổ sung (hỗ trợ sửa lại)
        clearPunches(rec);
        if (req.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT) {
            dayProcessor.applyManualFullDay(
                    rec,
                    req.getRequestedStart(),
                    req.getRequestedEnd(),
                    req.getRequestedAfternoonStart(),
                    req.getRequestedAfternoonEnd());
        } else {
            AttendanceShiftScope scope = req.getUpdateKind() == AttendanceUpdateKind.AFTERNOON_SUPPLEMENT
                    ? AttendanceShiftScope.AFTERNOON
                    : AttendanceShiftScope.MORNING;
            dayProcessor.applyManualShift(rec, scope, req.getRequestedStart(), req.getRequestedEnd());
        }
        String noteLine = QUANG_TRUNG_NOTE_MARKER + " — không trừ phạt quên chấm";
        if (req.getReason() != null && !req.getReason().isBlank()) {
            noteLine += ": " + req.getReason().trim();
        }
        rec.setNote(replaceQuangTrungNote(rec.getNote(), noteLine));
        rec = attendanceRecordRepository.save(rec);
        return toMap(rec);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void deleteQuangTrungSupplement(Long employeeId, LocalDate workDate) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, workDate)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không có công Quang Trung ngày này"));
        if (!isQuangTrungNote(rec.getNote())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày này không có công Quang Trung để xóa");
        }
        resetAttendanceAfterQuangTrungDelete(rec);
        rec.setNote(stripQuangTrungNotes(rec.getNote()));
        if (isEmptyAttendanceRecord(rec)) {
            attendanceRecordRepository.delete(rec);
            return;
        }
        attendanceRecordRepository.save(rec);
    }

    private void resetAttendanceAfterQuangTrungDelete(AttendanceRecord rec) {
        clearPunches(rec);
        rec.setMorningWorkUnits(java.math.BigDecimal.ZERO);
        rec.setAfternoonWorkUnits(java.math.BigDecimal.ZERO);
        rec.setOvertimeWorkUnits(java.math.BigDecimal.ZERO);
        rec.setLateMinutes(0);
        rec.setForgotShifts(null);
        dayProcessor.applyToRecord(rec);
    }

    private static boolean isEmptyAttendanceRecord(AttendanceRecord rec) {
        java.math.BigDecimal ot = rec.getOvertimeWorkUnits() != null
                ? rec.getOvertimeWorkUnits() : java.math.BigDecimal.ZERO;
        boolean noUnits = rec.getMorningWorkUnits().add(rec.getAfternoonWorkUnits()).add(ot)
                .compareTo(java.math.BigDecimal.ZERO) == 0;
        boolean noNote = rec.getNote() == null || rec.getNote().isBlank();
        return noUnits && noNote && "ABSENT".equals(rec.getStatus());
    }

    private void clearPunches(AttendanceRecord rec) {
        rec.setPunchTimesJson("[]");
        rec.setCheckIn(null);
        rec.setCheckOut(null);
        rec.setMorningCheckIn(null);
        rec.setMorningCheckOut(null);
        rec.setAfternoonCheckIn(null);
        rec.setAfternoonCheckOut(null);
    }

    private Map<String, Object> quangTrungView(AttendanceRecord rec) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("exists", true);
        m.put("workDate", rec.getWorkDate().toString());
        m.put("updateKind", detectQuangTrungUpdateKind(rec).name());
        m.put("reason", extractQuangTrungReason(rec.getNote()));
        m.put("morningCheckIn", timeOrEmpty(rec.getMorningCheckIn()));
        m.put("morningCheckOut", timeOrEmpty(rec.getMorningCheckOut()));
        m.put("afternoonCheckIn", timeOrEmpty(rec.getAfternoonCheckIn()));
        m.put("afternoonCheckOut", timeOrEmpty(rec.getAfternoonCheckOut()));
        m.put("status", rec.getStatus());
        m.put("note", rec.getNote() != null ? rec.getNote() : "");
        return m;
    }

    private static AttendanceUpdateKind detectQuangTrungUpdateKind(AttendanceRecord rec) {
        boolean morning = rec.getMorningCheckIn() != null || rec.getMorningCheckOut() != null
                || rec.getMorningWorkUnits().compareTo(java.math.BigDecimal.ZERO) > 0;
        boolean afternoon = rec.getAfternoonCheckIn() != null || rec.getAfternoonCheckOut() != null
                || rec.getAfternoonWorkUnits().compareTo(java.math.BigDecimal.ZERO) > 0;
        if (morning && afternoon) {
            return AttendanceUpdateKind.FULL_DAY_SUPPLEMENT;
        }
        if (afternoon) {
            return AttendanceUpdateKind.AFTERNOON_SUPPLEMENT;
        }
        return AttendanceUpdateKind.MORNING_SUPPLEMENT;
    }

    private static boolean isQuangTrungNote(String note) {
        return note != null && note.contains(QUANG_TRUNG_NOTE_MARKER);
    }

    private static String extractQuangTrungReason(String note) {
        if (note == null || note.isBlank()) {
            return "";
        }
        for (String part : note.split(";")) {
            String p = part.trim();
            if (!p.contains(QUANG_TRUNG_NOTE_MARKER)) {
                continue;
            }
            int colon = p.indexOf(':');
            if (colon >= 0 && colon < p.length() - 1) {
                return p.substring(colon + 1).trim();
            }
            return "";
        }
        return "";
    }

    private static String replaceQuangTrungNote(String existing, String newLine) {
        String stripped = stripQuangTrungNotes(existing);
        if (stripped == null || stripped.isBlank()) {
            return newLine;
        }
        return stripped + "; " + newLine;
    }

    private static String stripQuangTrungNotes(String existing) {
        if (existing == null || existing.isBlank()) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (String part : existing.split(";")) {
            String p = part.trim();
            if (p.isEmpty() || p.contains(QUANG_TRUNG_NOTE_MARKER)) {
                continue;
            }
            if (sb.length() > 0) {
                sb.append("; ");
            }
            sb.append(p);
        }
        return sb.toString();
    }

    private static String timeOrEmpty(java.time.LocalTime t) {
        return t != null ? t.toString() : "";
    }

    private static void validateQuangTrungSupplement(QuangTrungSupplementRequest req) {
        if (req.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT
                && (req.getRequestedAfternoonStart() == null || req.getRequestedAfternoonEnd() == null)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Bổ sung cả ngày cần nhập khung giờ ca sáng và ca chiều");
        }
    }

    public static final String CONG_HO_NOTE_MARKER = "Bổ sung công hộ";

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional(readOnly = true)
    public Map<String, Object> getCongHoSupplement(Long employeeId, LocalDate workDate) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanViewAttendance(emp);
        AttendanceRecord rec = attendanceRecordRepository.findByEmployeeAndWorkDate(emp, workDate).orElse(null);
        if (rec == null || !isCongHoNote(rec.getNote())) {
            return Map.of("exists", false, "workDate", workDate.toString());
        }
        return congHoView(rec);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> applyCongHoSupplement(Long employeeId, CongHoSupplementRequest req) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        validateCongHoSupplement(req);
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, req.getWorkDate())
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(emp)
                        .workDate(req.getWorkDate())
                        .status("ABSENT")
                        .build());
        clearPunches(rec);
        if (req.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT) {
            dayProcessor.applyManualFullDay(
                    rec,
                    req.getRequestedStart(),
                    req.getRequestedEnd(),
                    req.getRequestedAfternoonStart(),
                    req.getRequestedAfternoonEnd());
        } else {
            AttendanceShiftScope scope = req.getUpdateKind() == AttendanceUpdateKind.AFTERNOON_SUPPLEMENT
                    ? AttendanceShiftScope.AFTERNOON
                    : AttendanceShiftScope.MORNING;
            dayProcessor.applyManualShift(rec, scope, req.getRequestedStart(), req.getRequestedEnd());
        }
        String noteLine = CONG_HO_NOTE_MARKER + " — không trừ phạt quên chấm";
        if (req.getReason() != null && !req.getReason().isBlank()) {
            noteLine += ": " + req.getReason().trim();
        }
        rec.setNote(replaceCongHoNote(rec.getNote(), noteLine));
        rec = attendanceRecordRepository.save(rec);
        return toMap(rec);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void deleteCongHoSupplement(Long employeeId, LocalDate workDate) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, workDate)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không có công hộ ngày này"));
        if (!isCongHoNote(rec.getNote())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày này không có công hộ để xóa");
        }
        resetAttendanceAfterQuangTrungDelete(rec);
        rec.setNote(stripCongHoNotes(rec.getNote()));
        if (isEmptyAttendanceRecord(rec)) {
            attendanceRecordRepository.delete(rec);
            return;
        }
        attendanceRecordRepository.save(rec);
    }

    private Map<String, Object> congHoView(AttendanceRecord rec) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("exists", true);
        m.put("workDate", rec.getWorkDate().toString());
        m.put("updateKind", detectQuangTrungUpdateKind(rec).name());
        m.put("reason", extractCongHoReason(rec.getNote()));
        m.put("morningCheckIn", timeOrEmpty(rec.getMorningCheckIn()));
        m.put("morningCheckOut", timeOrEmpty(rec.getMorningCheckOut()));
        m.put("afternoonCheckIn", timeOrEmpty(rec.getAfternoonCheckIn()));
        m.put("afternoonCheckOut", timeOrEmpty(rec.getAfternoonCheckOut()));
        m.put("status", rec.getStatus());
        m.put("note", rec.getNote() != null ? rec.getNote() : "");
        return m;
    }

    private static boolean isCongHoNote(String note) {
        return note != null && note.contains(CONG_HO_NOTE_MARKER);
    }

    private static String extractCongHoReason(String note) {
        if (note == null || note.isBlank()) {
            return "";
        }
        for (String part : note.split(";")) {
            String p = part.trim();
            if (!p.contains(CONG_HO_NOTE_MARKER)) {
                continue;
            }
            int colon = p.indexOf(':');
            if (colon >= 0 && colon < p.length() - 1) {
                return p.substring(colon + 1).trim();
            }
            return "";
        }
        return "";
    }

    private static String replaceCongHoNote(String existing, String newLine) {
        String stripped = stripCongHoNotes(existing);
        if (stripped == null || stripped.isBlank()) {
            return newLine;
        }
        return stripped + "; " + newLine;
    }

    private static String stripCongHoNotes(String existing) {
        if (existing == null || existing.isBlank()) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (String part : existing.split(";")) {
            String p = part.trim();
            if (p.isEmpty() || p.contains(CONG_HO_NOTE_MARKER)) {
                continue;
            }
            if (sb.length() > 0) {
                sb.append("; ");
            }
            sb.append(p);
        }
        return sb.toString();
    }

    private static void validateCongHoSupplement(CongHoSupplementRequest req) {
        if (req.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT
                && (req.getRequestedAfternoonStart() == null || req.getRequestedAfternoonEnd() == null)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Bổ sung cả ngày cần nhập khung giờ ca sáng và ca chiều");
        }
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public int recalculateMonth(int year, int month) {
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        List<AttendanceRecord> all = attendanceRecordRepository.findByWorkDateBetweenWithEmployee(from, to);
        Set<Long> employeeIds = all.stream().map(r -> r.getEmployee().getId()).collect(Collectors.toSet());
        Set<String> monthKeys = continuousShiftService.monthKeysForEmployees(employeeIds, from, to);
        Set<LocalDate> holidays = holidayWorkDayService.datesInRange(from, to);
        dayProcessor.runWithContinuousShiftCache(monthKeys, () ->
                dayProcessor.runWithHolidayCache(holidays, () -> {
                    for (AttendanceRecord rec : all) {
                        dayProcessor.applyToRecord(rec);
                    }
                }));
        attendanceRecordRepository.saveAll(all);
        return all.size();
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public int recalculateEmployeeMonth(Long employeeId, int year, int month) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        YearMonth ym = YearMonth.of(year, month);
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        List<AttendanceRecord> records = attendanceRecordRepository
                .findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to);
        Set<String> monthKeys = continuousShiftService.monthKeysForEmployees(Set.of(employeeId), from, to);
        Set<LocalDate> holidays = holidayWorkDayService.datesInRange(from, to);
        dayProcessor.runWithContinuousShiftCache(monthKeys, () ->
                dayProcessor.runWithHolidayCache(holidays, () -> {
                    for (AttendanceRecord rec : records) {
                        dayProcessor.applyToRecord(rec);
                    }
                }));
        attendanceRecordRepository.saveAll(records);
        return records.size();
    }

    private void assertCanViewAttendance(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() == UserRole.ADMIN
                || current.getRole() == UserRole.HR
                || current.getRole() == UserRole.HEAD_DEPARTMENT
                || current.getRole() == UserRole.HEAD_NURSING) {
            return;
        }
        Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
        if (self == null || !self.getId().equals(target.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem bảng công");
        }
    }

    private Map<String, Object> toMap(AttendanceRecord r) {
        BigDecimal morning = r.getMorningWorkUnits() != null ? r.getMorningWorkUnits() : java.math.BigDecimal.ZERO;
        BigDecimal afternoon = r.getAfternoonWorkUnits() != null ? r.getAfternoonWorkUnits() : java.math.BigDecimal.ZERO;
        BigDecimal overtime = r.getOvertimeWorkUnits() != null ? r.getOvertimeWorkUnits() : java.math.BigDecimal.ZERO;
        String note = r.getNote() != null ? r.getNote() : "";
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", r.getEmployee().getId());
        m.put("workDate", r.getWorkDate().toString());
        m.put("checkIn", r.getCheckIn() != null ? r.getCheckIn().toString() : "");
        m.put("checkOut", r.getCheckOut() != null ? r.getCheckOut().toString() : "");
        m.put("morningCheckIn", r.getMorningCheckIn() != null ? r.getMorningCheckIn().toString() : "");
        m.put("morningCheckOut", r.getMorningCheckOut() != null ? r.getMorningCheckOut().toString() : "");
        m.put("afternoonCheckIn", r.getAfternoonCheckIn() != null ? r.getAfternoonCheckIn().toString() : "");
        m.put("afternoonCheckOut", r.getAfternoonCheckOut() != null ? r.getAfternoonCheckOut().toString() : "");
        m.put("morningWorkUnits", morning);
        m.put("afternoonWorkUnits", afternoon);
        m.put("overtimeWorkUnits", overtime);
        m.put("totalWorkUnits", morning.add(afternoon).add(overtime));
        m.put("lateMinutes", r.getLateMinutes());
        m.put("lateMinutesExempt", r.isLateMinutesExempt());
        m.put("forgotShifts", r.getForgotShifts() != null ? r.getForgotShifts() : "");
        m.put("status", r.getStatus());
        m.put("note", note);
        m.put("quangTrung", isQuangTrungNote(note));
        m.put("congHo", isCongHoNote(note));
        m.put("deployment", note.contains("Điều động làm thêm") || note.contains("Điều động trong ca"));
        m.put("punchTimes", dayProcessor.resolvePunches(r).stream().map(Object::toString).toList());
        return m;
    }
}
