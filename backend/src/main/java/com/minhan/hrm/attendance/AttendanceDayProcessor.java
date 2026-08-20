package com.minhan.hrm.attendance;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.AttendanceShiftScope;
import com.minhan.hrm.entity.ExplanationKind;
import com.minhan.hrm.service.AttendanceShiftScheduleService;
import com.minhan.hrm.service.ContinuousShiftService;
import com.minhan.hrm.service.HolidayWorkDayService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.function.Supplier;

@Component
@RequiredArgsConstructor
public class AttendanceDayProcessor {

    private static final ThreadLocal<Set<String>> CONTINUOUS_SHIFT_MONTH_KEYS = new ThreadLocal<>();
    private static final ThreadLocal<Set<LocalDate>> HOLIDAY_WORK_DATES = new ThreadLocal<>();
    private static final BigDecimal TWO = BigDecimal.valueOf(2);

    private final ObjectMapper objectMapper;
    private final AttendanceShiftScheduleService shiftScheduleService;
    private final ContinuousShiftService continuousShiftService;
    private final HolidayWorkDayService holidayWorkDayService;

    public void applyToRecord(AttendanceRecord rec) {
        // Gỡ ghi chú điều động không có mã đơn duyệt — tránh cộng trùng / tính đơn chưa duyệt
        String previousNote = rec.getNote() == null ? "" : rec.getNote().trim();
        String cleanedNote = dropUnmarkedDeploymentNotes(previousNote);
        if (!cleanedNote.equals(previousNote)) {
            rec.setNote(cleanedNote.isBlank() ? null : cleanedNote);
        }
        SeminarProtection seminar = extractSeminarProtection(rec.getNote());
        // Ngày nghỉ phép / công tác đã duyệt — không ghi đè bằng chấm công / tính lại
        // (Điều động làm thêm không khóa ngày — vẫn cho chấm công chính)
        if ("LEAVE".equals(rec.getStatus())
                || "UNPAID_LEAVE".equals(rec.getStatus())
                || "BUSINESS_TRIP".equals(rec.getStatus())
                || ("SEMINAR".equals(rec.getStatus()) && seminar == null)) {
            return;
        }
        DeploymentBonusSplit deployment = extractDeploymentBonusSplit(rec.getNote());
        InsideDeploymentRequirement insideDeployment =
                extractInsideDeploymentRequirement(rec.getNote());
        List<LocalTime> punches = resolvePunches(rec);
        if (rec.getPunchTimesJson() == null || rec.getPunchTimesJson().isBlank()) {
            rec.setPunchTimesJson(writePunches(punches));
        }
        AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(
                rec.getEmployee() != null ? rec.getEmployee().getId() : null, rec.getWorkDate());

        if (isContinuousShift(rec) && (seminar == null || seminar.scope() == AttendanceShiftScope.FULL_DAY)) {
            applyContinuousShift(rec, punches, schedule);
            DeploymentPunches deploymentPunches =
                    resolveInsideDeploymentPunches(punches, schedule, insideDeployment);
            rec.setOvertimeWorkUnits(BigDecimal.ZERO);
            applyDeploymentBonuses(
                    rec, filterDeploymentBonuses(deployment, insideDeployment, deploymentPunches));
            applyHolidayWorkMultiplier(rec);
            applySeminarProtection(rec, schedule, seminar);
            return;
        }

        ShiftAssignment shifts = assignShifts(punches, schedule);
        DeploymentPunches deploymentPunches =
                resolveInsideDeploymentPunches(punches, schedule, insideDeployment);
        shifts = mergeInsideDeploymentPunches(shifts, insideDeployment, deploymentPunches);
        deployment = filterDeploymentBonuses(deployment, insideDeployment, deploymentPunches);

        rec.setMorningCheckIn(shifts.morningIn());
        rec.setMorningCheckOut(shifts.morningOut());
        rec.setAfternoonCheckIn(shifts.afternoonIn());
        rec.setAfternoonCheckOut(shifts.afternoonOut());

        boolean morningOk = shifts.morningCredited();
        boolean afternoonOk = shifts.afternoonCredited();
        rec.setMorningWorkUnits(morningOk ? schedule.morningUnits() : BigDecimal.ZERO);
        rec.setAfternoonWorkUnits(afternoonOk ? schedule.afternoonUnits() : BigDecimal.ZERO);
        // Luôn reset ngoài giờ trước khi áp bonus từ ghi chú — tránh OT “dính” sau khi thu hồi/từ chối điều động
        rec.setOvertimeWorkUnits(BigDecimal.ZERO);
        applyDeploymentBonuses(rec, deployment);
        applyHolidayWorkMultiplier(rec);

        rec.setForgotShifts(buildForgotShifts(
                shifts, morningOk, afternoonOk, insideDeployment, seminar));

        applyLateMinutes(rec, schedule, shifts, insideDeployment, seminar);

        finalizeStatus(rec, shifts.morningIn(), shifts.morningOut(), shifts.afternoonOut());
        applySeminarProtection(rec, schedule, seminar);
    }

    private boolean isContinuousShift(AttendanceRecord rec) {
        Set<String> cache = CONTINUOUS_SHIFT_MONTH_KEYS.get();
        if (cache != null) {
            return cache.contains(ContinuousShiftService.dayKey(rec.getEmployee().getId(), rec.getWorkDate()));
        }
        return continuousShiftService.isContinuousShift(rec.getEmployee().getId(), rec.getWorkDate());
    }

    /** Chạy xử lý hàng loạt với cache ca thông tầm theo ngày đã tải trước (import SQL, tính lại tháng). */
    public void runWithContinuousShiftCache(Set<String> dayKeys, Runnable action) {
        CONTINUOUS_SHIFT_MONTH_KEYS.set(dayKeys);
        try {
            action.run();
        } finally {
            CONTINUOUS_SHIFT_MONTH_KEYS.remove();
        }
    }

    public <T> T callWithContinuousShiftCache(Set<String> dayKeys, Supplier<T> action) {
        CONTINUOUS_SHIFT_MONTH_KEYS.set(dayKeys);
        try {
            return action.get();
        } finally {
            CONTINUOUS_SHIFT_MONTH_KEYS.remove();
        }
    }

    /** Cache ngày lễ khi tính lại / import hàng loạt. */
    public void runWithHolidayCache(Set<LocalDate> holidayDates, Runnable action) {
        HOLIDAY_WORK_DATES.set(holidayDates);
        try {
            action.run();
        } finally {
            HOLIDAY_WORK_DATES.remove();
        }
    }

    /** Ngày lễ đi làm: nhân đôi công ca (sáng + chiều). */
    private void applyHolidayWorkMultiplier(AttendanceRecord rec) {
        if (rec.getWorkDate() == null) {
            return;
        }
        Set<LocalDate> cache = HOLIDAY_WORK_DATES.get();
        boolean holiday = cache != null
                ? cache.contains(rec.getWorkDate())
                : holidayWorkDayService.isHoliday(rec.getWorkDate());
        if (!holiday) {
            return;
        }
        BigDecimal morning = nz(rec.getMorningWorkUnits());
        BigDecimal afternoon = nz(rec.getAfternoonWorkUnits());
        if (morning.add(afternoon).compareTo(BigDecimal.ZERO) <= 0) {
            return;
        }
        rec.setMorningWorkUnits(morning.multiply(TWO));
        rec.setAfternoonWorkUnits(afternoon.multiply(TWO));
    }

    /** Ca thông tầm: chỉ cần giờ vào (đầu ngày) và giờ ra (cuối ngày), không bắt buộc chấm giữa trưa. */
    private void applyContinuousShift(
            AttendanceRecord rec, List<LocalTime> punches, AttendanceShiftSchedule schedule) {
        List<LocalTime> available = new ArrayList<>(punches.stream().sorted().distinct().toList());
        LocalTime dayStart = schedule.continuousDayStart();
        LocalTime dayEnd = schedule.continuousDayEnd();
        AttendancePunchWindows w = schedule.punchWindows();

        LocalTime dayIn = pickMinInWindow(
                available, dayStart, w.morningInBeforeMin(), w.morningInAfterMin());

        LocalTime dayOut = pickMaxInWindow(
                available, dayEnd, w.afternoonOutBeforeMin(), w.afternoonOutAfterMin());

        rec.setMorningCheckIn(dayIn);
        rec.setMorningCheckOut(null);
        rec.setAfternoonCheckIn(null);
        rec.setAfternoonCheckOut(dayOut);

        boolean fullDay = dayIn != null && dayOut != null;
        rec.setMorningWorkUnits(fullDay ? schedule.morningUnits() : BigDecimal.ZERO);
        rec.setAfternoonWorkUnits(fullDay ? schedule.afternoonUnits() : BigDecimal.ZERO);

        List<String> forgot = new ArrayList<>();
        if (dayIn == null) {
            forgot.add("MORNING");
        }
        if (dayOut == null) {
            forgot.add("AFTERNOON");
        }
        rec.setForgotShifts(forgot.isEmpty() ? null : String.join(",", forgot));

        if (rec.isLateMinutesExempt()) {
            rec.setLateMinutes(0);
        } else {
            int late = 0;
            if (dayIn != null) {
                late += minutesLate(dayIn, dayStart);
            }
            if (dayOut != null) {
                late += minutesEarly(dayOut, dayEnd);
            }
            rec.setLateMinutes(late);
        }

        finalizeStatus(rec, dayIn, null, dayOut);
    }

    public List<LocalTime> resolvePunches(AttendanceRecord rec) {
        if (rec.getPunchTimesJson() != null && !rec.getPunchTimesJson().isBlank()) {
            try {
                List<String> raw = objectMapper.readValue(rec.getPunchTimesJson(), new TypeReference<>() {});
                return raw.stream().map(LocalTime::parse).sorted().toList();
            } catch (Exception ignored) {
                // fall through
            }
        }
        List<LocalTime> list = new ArrayList<>();
        if (rec.getCheckIn() != null) {
            list.add(rec.getCheckIn());
        }
        if (rec.getCheckOut() != null && !rec.getCheckOut().equals(rec.getCheckIn())) {
            list.add(rec.getCheckOut());
        }
        if (rec.getMorningCheckIn() != null) {
            list.add(rec.getMorningCheckIn());
        }
        if (rec.getMorningCheckOut() != null) {
            list.add(rec.getMorningCheckOut());
        }
        if (rec.getAfternoonCheckIn() != null) {
            list.add(rec.getAfternoonCheckIn());
        }
        if (rec.getAfternoonCheckOut() != null) {
            list.add(rec.getAfternoonCheckOut());
        }
        return list.stream().distinct().sorted().toList();
    }

    public String writePunches(List<LocalTime> punches) {
        try {
            List<String> s = punches.stream().map(LocalTime::toString).toList();
            return objectMapper.writeValueAsString(s);
        } catch (Exception e) {
            return "[]";
        }
    }

    public void setPunchesFromTimes(AttendanceRecord rec, List<LocalDateTimeHolder> dateTimes) {
        List<LocalTime> times = dateTimes.stream()
                .map(LocalDateTimeHolder::time)
                .sorted()
                .distinct()
                .toList();
        rec.setPunchTimesJson(writePunches(times));
        applyToRecord(rec);
    }

    public record LocalDateTimeHolder(LocalTime time) {
    }

    /**
     * Gán giờ vào/ra theo log máy: chỉ lấy quẹt nằm trong cửa sổ min/max quanh mốc giờ ca.
     * Không fallback ngoài cửa sổ — tránh gán nhầm (vd. 6h36 làm giờ ra ca sáng).
     */
    private static ShiftAssignment assignShifts(List<LocalTime> punches, AttendanceShiftSchedule schedule) {
        List<LocalTime> sorted = punches.stream().sorted().distinct().toList();
        if (sorted.isEmpty()) {
            return ShiftAssignment.EMPTY;
        }

        LocalTime morningStart = schedule.morningStart();
        LocalTime morningEnd = schedule.morningEnd();
        LocalTime afternoonStart = schedule.afternoonStart();
        LocalTime afternoonEnd = schedule.afternoonEnd();
        AttendancePunchWindows w = schedule.punchWindows();

        List<LocalTime> available = new ArrayList<>(sorted);

        LocalTime morningIn = pickMinInWindow(
                available, morningStart, w.morningInBeforeMin(), w.morningInAfterMin());
        LocalTime morningOut = pickMaxInWindow(
                available, morningEnd, w.morningOutBeforeMin(), w.morningOutAfterMin());
        LocalTime afternoonIn = pickMinInWindow(
                available, afternoonStart, w.afternoonInBeforeMin(), w.afternoonInAfterMin());
        LocalTime afternoonOut = pickMaxInWindow(
                available, afternoonEnd, w.afternoonOutBeforeMin(), w.afternoonOutAfterMin());

        return new ShiftAssignment(morningIn, morningOut, afternoonIn, afternoonOut);
    }

    private static LocalTime pickMinInWindow(
            List<LocalTime> available, LocalTime anchor, int beforeMin, int afterMin) {
        LocalTime best = null;
        for (LocalTime t : available) {
            if (!inWindow(t, anchor, beforeMin, afterMin)) {
                continue;
            }
            if (best == null || t.isBefore(best)) {
                best = t;
            }
        }
        if (best != null) {
            available.remove(best);
        }
        return best;
    }

    private static LocalTime pickMaxInWindow(
            List<LocalTime> available, LocalTime anchor, int beforeMin, int afterMin) {
        LocalTime best = null;
        for (LocalTime t : available) {
            if (!inWindow(t, anchor, beforeMin, afterMin)) {
                continue;
            }
            if (best == null || t.isAfter(best)) {
                best = t;
            }
        }
        if (best != null) {
            available.remove(best);
        }
        return best;
    }

    private static boolean inWindow(LocalTime punch, LocalTime anchor, int beforeMin, int afterMin) {
        LocalTime from = anchor.minusMinutes(beforeMin);
        LocalTime to = anchor.plusMinutes(afterMin);
        return !punch.isBefore(from) && !punch.isAfter(to);
    }

    /**
     * Phân loại log thuộc nửa buổi sáng hay chiều khi cập nhật/giải trình theo ca.
     * Không dùng đúng mốc kết thúc ca sáng ({@code morningEnd}) — giờ ra trễ vài phút
     * (vd. 11:48 khi ca kết thúc 11:45) vẫn phải thuộc sáng, nếu không đơn cập nhật ca chiều
     * sẽ xóa nhầm giờ ra sáng khi đồng bộ lại.
     */
    static boolean isMorningPunch(LocalTime time, AttendanceShiftSchedule schedule) {
        if (time == null || schedule == null || schedule.morningEnd() == null) {
            return false;
        }
        LocalTime morningEnd = schedule.morningEnd();
        LocalTime afternoonStart = schedule.afternoonStart();
        if (afternoonStart != null && afternoonStart.isAfter(morningEnd)) {
            long gapMin = java.time.Duration.between(morningEnd, afternoonStart).toMinutes();
            LocalTime split = morningEnd.plusMinutes(Math.max(1L, gapMin / 2));
            return time.isBefore(split);
        }
        return !time.isAfter(morningEnd);
    }

    private static int minutesLate(LocalTime actual, LocalTime expected) {
        // Làm tròn về phút (bỏ giây) — khớp giờ hiển thị trên UI / máy chấm
        LocalTime a = truncateToMinute(actual);
        LocalTime e = truncateToMinute(expected);
        if (!a.isAfter(e)) {
            return 0;
        }
        return (int) java.time.Duration.between(e, a).toMinutes();
    }

    private static int minutesEarly(LocalTime actual, LocalTime expected) {
        LocalTime a = truncateToMinute(actual);
        LocalTime e = truncateToMinute(expected);
        if (!a.isBefore(e)) {
            return 0;
        }
        return (int) java.time.Duration.between(a, e).toMinutes();
    }

    private static LocalTime truncateToMinute(LocalTime t) {
        return t.withSecond(0).withNano(0);
    }

    private record ShiftAssignment(
            LocalTime morningIn,
            LocalTime morningOut,
            LocalTime afternoonIn,
            LocalTime afternoonOut) {

        static final ShiftAssignment EMPTY = new ShiftAssignment(null, null, null, null);

        boolean morningCredited() {
            return morningIn != null && morningOut != null;
        }

        boolean afternoonCredited() {
            return afternoonIn != null && afternoonOut != null;
        }
    }

    private record InsideDeploymentRequirement(
            LocalTime morningStart,
            LocalTime morningEnd,
            LocalTime afternoonStart,
            LocalTime afternoonEnd) {

        static final InsideDeploymentRequirement NONE =
                new InsideDeploymentRequirement(null, null, null, null);

        boolean hasMorning() {
            return morningStart != null && morningEnd != null;
        }

        boolean hasAfternoon() {
            return afternoonStart != null && afternoonEnd != null;
        }
    }

    private record DeploymentPunches(
            LocalTime morningIn,
            LocalTime morningOut,
            LocalTime afternoonIn,
            LocalTime afternoonOut) {

        static final DeploymentPunches EMPTY =
                new DeploymentPunches(null, null, null, null);

        boolean morningCredited() {
            return morningIn != null && morningOut != null;
        }

        boolean afternoonCredited() {
            return afternoonIn != null && afternoonOut != null;
        }
    }

    /**
     * Thiếu giờ vào hoặc giờ ra của ca → cần cập nhật quên chấm.
     * Ca chiều hoàn toàn không có log nhưng ca sáng đủ → quên cả ca chiều.
     */
    private static String buildForgotShifts(
            ShiftAssignment shifts,
            boolean morningOk,
            boolean afternoonOk,
            InsideDeploymentRequirement deployment,
            SeminarProtection seminar) {
        List<String> forgot = new ArrayList<>();
        if (!morningOk && needsMorningUpdate(shifts, afternoonOk)) {
            forgot.add("MORNING");
        }
        if (!afternoonOk && needsAfternoonUpdate(shifts, morningOk)) {
            forgot.add("AFTERNOON");
        }
        // Ca điều động đã duyệt luôn phải hiện đúng ca thiếu chấm để nhân viên
        // có thể lập đơn cập nhật công, kể cả khi hoàn toàn chưa có log trong ngày.
        if (deployment.hasMorning() && !morningOk && !forgot.contains("MORNING")) {
            forgot.add("MORNING");
        }
        if (deployment.hasAfternoon() && !afternoonOk && !forgot.contains("AFTERNOON")) {
            forgot.add("AFTERNOON");
        }
        if (protectsMorning(seminar)) {
            forgot.remove("MORNING");
        }
        if (protectsAfternoon(seminar)) {
            forgot.remove("AFTERNOON");
        }
        return forgot.isEmpty() ? null : String.join(",", forgot);
    }

    private static boolean needsMorningUpdate(ShiftAssignment shifts, boolean afternoonOk) {
        if (shifts.morningIn() != null || shifts.morningOut() != null) {
            return true;
        }
        return shifts.afternoonIn() == null && shifts.afternoonOut() == null && !afternoonOk;
    }

    private static boolean needsAfternoonUpdate(ShiftAssignment shifts, boolean morningOk) {
        if (shifts.afternoonIn() != null || shifts.afternoonOut() != null) {
            return true;
        }
        return morningOk;
    }

    /** Áp dụng giờ bổ sung cả ngày (4 mốc chấm công). */
    public void applyManualFullDay(
            AttendanceRecord rec,
            LocalTime morningStart,
            LocalTime morningEnd,
            LocalTime afternoonStart,
            LocalTime afternoonEnd) {
        AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(
                rec.getEmployee() != null ? rec.getEmployee().getId() : null, rec.getWorkDate());
        LocalTime mStart = morningStart;
        LocalTime mEnd = morningEnd;
        LocalTime aStart = afternoonStart;
        LocalTime aEnd = afternoonEnd;

        if (aStart == null || aEnd == null) {
            if (mEnd != null && mEnd.isAfter(schedule.afternoonStart())) {
                aEnd = mEnd;
                aStart = schedule.afternoonStart();
                mEnd = schedule.morningEnd();
            } else {
                if (mEnd == null) {
                    mEnd = schedule.morningEnd();
                }
                aStart = schedule.afternoonStart();
                aEnd = schedule.afternoonEnd();
            }
        }

        if (isContinuousShift(rec)) {
            List<LocalTime> punches = new ArrayList<>();
            if (mStart != null) {
                punches.add(mStart);
            }
            if (aEnd != null) {
                punches.add(aEnd);
            }
            rec.setPunchTimesJson(writePunches(punches.stream().sorted().distinct().toList()));
            applyToRecord(rec);
            return;
        }
        List<LocalTime> punches = new ArrayList<>();
        if (mStart != null) {
            punches.add(mStart);
        }
        if (mEnd != null) {
            punches.add(mEnd);
        }
        if (aStart != null) {
            punches.add(aStart);
        }
        if (aEnd != null) {
            punches.add(aEnd);
        }
        rec.setPunchTimesJson(writePunches(punches.stream().sorted().distinct().toList()));
        applyToRecord(rec);
    }

    /** Áp dụng giờ từ đơn cập nhật công đã duyệt. */
    public void applyManualShift(
            AttendanceRecord rec,
            com.minhan.hrm.entity.AttendanceShiftScope scope,
            LocalTime start,
            LocalTime end) {
        AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(
                rec.getEmployee() != null ? rec.getEmployee().getId() : null, rec.getWorkDate());
        if (isContinuousShift(rec)) {
            List<LocalTime> punches = new ArrayList<>();
            if (start != null) {
                punches.add(start);
            }
            if (end != null) {
                punches.add(end);
            }
            rec.setPunchTimesJson(writePunches(punches.stream().sorted().distinct().toList()));
            applyToRecord(rec);
            return;
        }
        List<LocalTime> punches = new ArrayList<>(resolvePunches(rec));
        switch (scope) {
            case MORNING -> {
                punches.removeIf(t -> isMorningPunch(t, schedule));
                if (start != null) {
                    punches.add(start);
                }
                if (end != null) {
                    punches.add(end);
                }
            }
            case AFTERNOON -> {
                punches.removeIf(t -> !isMorningPunch(t, schedule));
                if (start != null) {
                    punches.add(start);
                }
                if (end != null) {
                    punches.add(end);
                }
            }
            case FULL_DAY -> {
                punches.clear();
                if (start != null) {
                    punches.add(start);
                }
                if (end != null) {
                    punches.add(end);
                }
                if (start != null && end != null && start.isBefore(schedule.morningEnd()) && end.isAfter(schedule.afternoonStart())) {
                    punches.add(schedule.morningEnd());
                    punches.add(schedule.afternoonStart());
                }
            }
        }
        rec.setPunchTimesJson(writePunches(punches.stream().sorted().distinct().toList()));
        applyToRecord(rec);
    }

    /**
     * Áp dụng giờ giải trình đã duyệt: thay giờ chấm công theo ca, tính lại phút muộn/về sớm (có thể giảm phạt).
     */
    public void applyExplainedTime(
            AttendanceRecord rec,
            AttendanceShiftScope scope,
            ExplanationKind kind,
            LocalTime explainedTime) {
        AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(
                rec.getEmployee() != null ? rec.getEmployee().getId() : null, rec.getWorkDate());
        if (isContinuousShift(rec)) {
            List<LocalTime> punches = new ArrayList<>(resolvePunches(rec));
            if (kind == ExplanationKind.LATE_ARRIVAL) {
                if (punches.isEmpty()) {
                    punches.add(explainedTime);
                } else {
                    punches.set(0, explainedTime);
                }
            } else {
                if (punches.isEmpty()) {
                    punches.add(explainedTime);
                } else if (punches.size() == 1) {
                    punches.add(explainedTime);
                } else {
                    punches.set(punches.size() - 1, explainedTime);
                }
            }
            rec.setLateMinutesExempt(false);
            rec.setPunchTimesJson(writePunches(punches.stream().sorted().distinct().toList()));
            applyToRecord(rec);
            return;
        }
        List<LocalTime> punches = new ArrayList<>(resolvePunches(rec));
        switch (scope) {
            case MORNING -> adjustShiftPunches(punches, true, kind, explainedTime, schedule);
            case AFTERNOON -> adjustShiftPunches(punches, false, kind, explainedTime, schedule);
            case FULL_DAY -> {
                if (kind == ExplanationKind.LATE_ARRIVAL) {
                    if (hasMorningPunch(punches, schedule)) {
                        adjustShiftPunches(punches, true, kind, explainedTime, schedule);
                    } else {
                        adjustShiftPunches(punches, false, kind, explainedTime, schedule);
                    }
                } else {
                    if (hasAfternoonPunch(punches, schedule)) {
                        adjustShiftPunches(punches, false, kind, explainedTime, schedule);
                    } else {
                        adjustShiftPunches(punches, true, kind, explainedTime, schedule);
                    }
                }
            }
        }
        rec.setLateMinutesExempt(false);
        rec.setPunchTimesJson(writePunches(punches.stream().sorted().distinct().toList()));
        applyToRecord(rec);
    }

    private static void adjustShiftPunches(
            List<LocalTime> punches,
            boolean morning,
            ExplanationKind kind,
            LocalTime explainedTime,
            AttendanceShiftSchedule schedule) {
        List<LocalTime> shift = morning
                ? punches.stream().filter(t -> isMorningPunch(t, schedule)).sorted().toList()
                : punches.stream().filter(t -> !isMorningPunch(t, schedule)).sorted().toList();
        punches.removeAll(shift);
        List<LocalTime> adjusted = new ArrayList<>(shift);
        if (kind == ExplanationKind.LATE_ARRIVAL) {
            if (adjusted.isEmpty()) {
                adjusted.add(explainedTime);
            } else {
                adjusted.set(0, explainedTime);
            }
        } else {
            if (adjusted.isEmpty()) {
                adjusted.add(explainedTime);
            } else if (adjusted.size() == 1) {
                adjusted.add(explainedTime);
            } else {
                adjusted.set(adjusted.size() - 1, explainedTime);
            }
        }
        punches.addAll(adjusted);
    }

    private static boolean hasMorningPunch(List<LocalTime> punches, AttendanceShiftSchedule schedule) {
        return punches.stream().anyMatch(t -> isMorningPunch(t, schedule));
    }

    private static boolean hasAfternoonPunch(List<LocalTime> punches, AttendanceShiftSchedule schedule) {
        return punches.stream().anyMatch(t -> !isMorningPunch(t, schedule));
    }

    private static void applyLateMinutes(
            AttendanceRecord rec,
            AttendanceShiftSchedule schedule,
            ShiftAssignment shifts,
            InsideDeploymentRequirement deployment,
            SeminarProtection seminar) {
        if (rec.isLateMinutesExempt()) {
            rec.setLateMinutes(0);
            return;
        }
        int late = 0;
        if (!protectsMorning(seminar) && shifts.morningIn() != null) {
            LocalTime expectedIn = deployment.hasMorning()
                    ? deployment.morningStart() : schedule.morningStart();
            LocalTime expectedOut = deployment.hasMorning()
                    ? deployment.morningEnd() : schedule.morningEnd();
            late += minutesLate(shifts.morningIn(), expectedIn);
            if (shifts.morningOut() != null) {
                late += minutesEarly(shifts.morningOut(), expectedOut);
            }
        }
        if (!protectsAfternoon(seminar) && shifts.afternoonIn() != null) {
            LocalTime expectedIn = deployment.hasAfternoon()
                    ? deployment.afternoonStart() : schedule.afternoonStart();
            LocalTime expectedOut = deployment.hasAfternoon()
                    ? deployment.afternoonEnd() : schedule.afternoonEnd();
            late += minutesLate(shifts.afternoonIn(), expectedIn);
            if (shifts.afternoonOut() != null) {
                late += minutesEarly(shifts.afternoonOut(), expectedOut);
            }
        }
        rec.setLateMinutes(late);
    }

    private static SeminarProtection extractSeminarProtection(String note) {
        if (note == null || note.isBlank()) {
            return null;
        }
        java.util.regex.Matcher matcher = java.util.regex.Pattern
                .compile("\\[SEMINAR:(MORNING|AFTERNOON|FULL_DAY):(PAID|UNPAID)]")
                .matcher(note);
        if (!matcher.find()) {
            return null;
        }
        return new SeminarProtection(
                AttendanceShiftScope.valueOf(matcher.group(1)),
                "PAID".equals(matcher.group(2)));
    }

    private static boolean protectsMorning(SeminarProtection seminar) {
        return seminar != null && (seminar.scope() == AttendanceShiftScope.MORNING
                || seminar.scope() == AttendanceShiftScope.FULL_DAY);
    }

    private static boolean protectsAfternoon(SeminarProtection seminar) {
        return seminar != null && (seminar.scope() == AttendanceShiftScope.AFTERNOON
                || seminar.scope() == AttendanceShiftScope.FULL_DAY);
    }

    private static void applySeminarProtection(
            AttendanceRecord rec,
            AttendanceShiftSchedule schedule,
            SeminarProtection seminar) {
        if (seminar == null) {
            return;
        }
        if (protectsMorning(seminar)) {
            rec.setMorningWorkUnits(seminar.withPay() ? schedule.morningUnits() : BigDecimal.ZERO);
        }
        if (protectsAfternoon(seminar)) {
            rec.setAfternoonWorkUnits(seminar.withPay() ? schedule.afternoonUnits() : BigDecimal.ZERO);
        }
        rec.setForgotShifts(removeForgotScope(rec.getForgotShifts(), seminar.scope()));
        if (seminar.scope() == AttendanceShiftScope.FULL_DAY) {
            rec.setLateMinutes(0);
        }
        rec.setStatus("SEMINAR");
    }

    private static String removeForgotScope(String forgot, AttendanceShiftScope scope) {
        if (forgot == null || forgot.isBlank()) {
            return null;
        }
        List<String> values = new ArrayList<>(List.of(forgot.split(",")));
        if (scope == AttendanceShiftScope.MORNING || scope == AttendanceShiftScope.FULL_DAY) {
            values.remove("MORNING");
        }
        if (scope == AttendanceShiftScope.AFTERNOON || scope == AttendanceShiftScope.FULL_DAY) {
            values.remove("AFTERNOON");
        }
        return values.isEmpty() ? null : String.join(",", values);
    }

    private record SeminarProtection(AttendanceShiftScope scope, boolean withPay) {
    }

    private static void finalizeStatus(
            AttendanceRecord rec, LocalTime morningIn, LocalTime morningOut, LocalTime afternoonOut) {
        BigDecimal overtime = rec.getOvertimeWorkUnits() != null ? rec.getOvertimeWorkUnits() : BigDecimal.ZERO;
        BigDecimal totalUnits = nz(rec.getMorningWorkUnits()).add(nz(rec.getAfternoonWorkUnits())).add(overtime);
        String status = totalUnits.compareTo(BigDecimal.ZERO) > 0
                ? (totalUnits.compareTo(new BigDecimal("0.99")) >= 0 ? "PRESENT" : "PARTIAL")
                : "ABSENT";
        rec.setStatus(status);
        if (morningIn != null) {
            rec.setCheckIn(morningIn);
        }
        LocalTime dayOut = afternoonOut != null ? afternoonOut : morningOut;
        if (dayOut != null) {
            rec.setCheckOut(dayOut);
        }
    }

    private record DeploymentBonusSplit(
            BigDecimal morning,
            boolean replaceMorning,
            BigDecimal afternoon,
            boolean replaceAfternoon,
            BigDecimal overtime) {
        static DeploymentBonusSplit zero() {
            return new DeploymentBonusSplit(
                    BigDecimal.ZERO, false, BigDecimal.ZERO, false, BigDecimal.ZERO);
        }
    }

    private static InsideDeploymentRequirement extractInsideDeploymentRequirement(String note) {
        if (note == null || note.isBlank()) {
            return InsideDeploymentRequirement.NONE;
        }
        java.util.regex.Matcher matcher = java.util.regex.Pattern.compile(
                "\\[DDTC:S=([0-9]{2}:[0-9]{2})-([0-9]{2}:[0-9]{2})|"
                        + "\\[DDTC:S=-")
                .matcher(note);
        LocalTime morningStart = null;
        LocalTime morningEnd = null;
        int markerStart = -1;
        if (matcher.find()) {
            markerStart = matcher.start();
            if (matcher.group(1) != null) {
                morningStart = LocalTime.parse(matcher.group(1));
                morningEnd = LocalTime.parse(matcher.group(2));
            }
        }
        if (markerStart < 0) {
            return InsideDeploymentRequirement.NONE;
        }
        int markerEnd = note.indexOf(']', markerStart);
        if (markerEnd < 0) {
            return InsideDeploymentRequirement.NONE;
        }
        String marker = note.substring(markerStart, markerEnd + 1);
        java.util.regex.Matcher afternoonMatcher = java.util.regex.Pattern.compile(
                "A=([0-9]{2}:[0-9]{2})-([0-9]{2}:[0-9]{2})")
                .matcher(marker);
        LocalTime afternoonStart = null;
        LocalTime afternoonEnd = null;
        if (afternoonMatcher.find()) {
            afternoonStart = LocalTime.parse(afternoonMatcher.group(1));
            afternoonEnd = LocalTime.parse(afternoonMatcher.group(2));
        }
        return new InsideDeploymentRequirement(
                morningStart, morningEnd, afternoonStart, afternoonEnd);
    }

    private static DeploymentPunches resolveInsideDeploymentPunches(
            List<LocalTime> punches,
            AttendanceShiftSchedule schedule,
            InsideDeploymentRequirement requirement) {
        if (!requirement.hasMorning() && !requirement.hasAfternoon()) {
            return DeploymentPunches.EMPTY;
        }
        List<LocalTime> available = new ArrayList<>(punches.stream().sorted().distinct().toList());
        AttendancePunchWindows windows = schedule.punchWindows();
        LocalTime morningIn = null;
        LocalTime morningOut = null;
        LocalTime afternoonIn = null;
        LocalTime afternoonOut = null;
        if (requirement.hasMorning()) {
            morningIn = pickMinInWindow(
                    available,
                    requirement.morningStart(),
                    windows.morningInBeforeMin(),
                    windows.morningInAfterMin());
            morningOut = pickMaxInWindow(
                    available,
                    requirement.morningEnd(),
                    windows.morningOutBeforeMin(),
                    windows.morningOutAfterMin());
        }
        if (requirement.hasAfternoon()) {
            afternoonIn = pickMinInWindow(
                    available,
                    requirement.afternoonStart(),
                    windows.afternoonInBeforeMin(),
                    windows.afternoonInAfterMin());
            afternoonOut = pickMaxInWindow(
                    available,
                    requirement.afternoonEnd(),
                    windows.afternoonOutBeforeMin(),
                    windows.afternoonOutAfterMin());
        }
        return new DeploymentPunches(morningIn, morningOut, afternoonIn, afternoonOut);
    }

    private static ShiftAssignment mergeInsideDeploymentPunches(
            ShiftAssignment shifts,
            InsideDeploymentRequirement requirement,
            DeploymentPunches deploymentPunches) {
        return new ShiftAssignment(
                requirement.hasMorning() ? deploymentPunches.morningIn() : shifts.morningIn(),
                requirement.hasMorning() ? deploymentPunches.morningOut() : shifts.morningOut(),
                requirement.hasAfternoon() ? deploymentPunches.afternoonIn() : shifts.afternoonIn(),
                requirement.hasAfternoon() ? deploymentPunches.afternoonOut() : shifts.afternoonOut());
    }

    private static DeploymentBonusSplit filterDeploymentBonuses(
            DeploymentBonusSplit deployment,
            InsideDeploymentRequirement requirement,
            DeploymentPunches punches) {
        if (!requirement.hasMorning() && !requirement.hasAfternoon()) {
            return deployment;
        }
        boolean morningOk = !requirement.hasMorning() || punches.morningCredited();
        boolean afternoonOk = !requirement.hasAfternoon() || punches.afternoonCredited();
        return new DeploymentBonusSplit(
                morningOk ? deployment.morning() : BigDecimal.ZERO,
                morningOk && deployment.replaceMorning(),
                afternoonOk ? deployment.afternoon() : BigDecimal.ZERO,
                afternoonOk && deployment.replaceAfternoon(),
                deployment.overtime());
    }

    private static void applyDeploymentBonuses(AttendanceRecord rec, DeploymentBonusSplit deployment) {
        if (deployment.replaceMorning() && deployment.morning().compareTo(BigDecimal.ZERO) > 0) {
            rec.setMorningWorkUnits(deployment.morning());
        } else if (deployment.morning().compareTo(BigDecimal.ZERO) > 0) {
            rec.setMorningWorkUnits(nz(rec.getMorningWorkUnits()).add(deployment.morning()));
        }
        if (deployment.replaceAfternoon() && deployment.afternoon().compareTo(BigDecimal.ZERO) > 0) {
            rec.setAfternoonWorkUnits(deployment.afternoon());
        } else if (deployment.afternoon().compareTo(BigDecimal.ZERO) > 0) {
            rec.setAfternoonWorkUnits(nz(rec.getAfternoonWorkUnits()).add(deployment.afternoon()));
        }
        // Gán cả khi = 0 để gỡ ngoài giờ sau khi bỏ ghi chú điều động
        rec.setOvertimeWorkUnits(nz(deployment.overtime()));
    }

    private static BigDecimal nz(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }

    /**
     * Parse công điều động từ ghi chú.
     * Chỉ tính các dòng đã gắn mã đơn duyệt {@code [DD:…]} / {@code [DDTC:…]} —
     * bỏ qua ghi chú điều động cũ/mồ côi (không mã) để tránh cộng trùng hoặc tính đơn chưa duyệt.
     * Mới: (=A sáng / =B chiều / +C ngoài giờ) — thay công ca khi ngày đã chấm
     * Mới: (+A sáng / +B chiều / +C ngoài giờ) — cộng thêm
     * Cũ 2 phần: (+A sáng / +B chiều)
     * Cũ 1 phần: (+X công) → ngoài giờ
     */
    private static DeploymentBonusSplit extractDeploymentBonusSplit(String note) {
        if (note == null || note.isBlank()) {
            return DeploymentBonusSplit.zero();
        }
        BigDecimal morning = BigDecimal.ZERO;
        boolean replaceMorning = false;
        BigDecimal afternoon = BigDecimal.ZERO;
        boolean replaceAfternoon = false;
        BigDecimal overtime = BigDecimal.ZERO;

        java.util.regex.Pattern flexible = java.util.regex.Pattern.compile(
                "([+=])([0-9]+(?:\\.[0-9]+)?) (sáng|chiều|ngoài giờ)");
        java.util.regex.Pattern three = java.util.regex.Pattern.compile(
                "Điều động làm thêm[^;]*\\(\\+([0-9]+(?:\\.[0-9]+)?) sáng\\s*/\\s*\\+([0-9]+(?:\\.[0-9]+)?) chiều\\s*/\\s*\\+([0-9]+(?:\\.[0-9]+)?) ngoài giờ\\)");
        java.util.regex.Pattern two = java.util.regex.Pattern.compile(
                "Điều động làm thêm[^;]*\\(\\+([0-9]+(?:\\.[0-9]+)?) sáng\\s*/\\s*\\+([0-9]+(?:\\.[0-9]+)?) chiều\\)");
        java.util.regex.Pattern one = java.util.regex.Pattern.compile(
                "Điều động làm thêm[^;]*\\(\\+([0-9]+(?:\\.[0-9]+)?) công\\)");

        for (String part : note.split(";")) {
            String segment = part.trim();
            if (!isApprovedDeploymentNoteSegment(segment)) {
                continue;
            }

            boolean segmentFlexible = false;
            java.util.regex.Matcher mf = flexible.matcher(segment);
            while (mf.find()) {
                segmentFlexible = true;
                boolean replace = "=".equals(mf.group(1));
                BigDecimal amount = parseBd(mf.group(2));
                switch (mf.group(3)) {
                    case "sáng" -> {
                        morning = morning.add(amount);
                        replaceMorning = replaceMorning || replace;
                    }
                    case "chiều" -> {
                        afternoon = afternoon.add(amount);
                        replaceAfternoon = replaceAfternoon || replace;
                    }
                    case "ngoài giờ" -> overtime = overtime.add(amount);
                    default -> { }
                }
            }
            if (segmentFlexible) {
                continue;
            }

            boolean segmentSplit = false;
            java.util.regex.Matcher m3 = three.matcher(segment);
            while (m3.find()) {
                segmentSplit = true;
                morning = morning.add(parseBd(m3.group(1)));
                afternoon = afternoon.add(parseBd(m3.group(2)));
                overtime = overtime.add(parseBd(m3.group(3)));
            }

            java.util.regex.Matcher m2 = two.matcher(segment);
            while (m2.find()) {
                String full = m2.group(0);
                if (full.contains("ngoài giờ")) {
                    continue;
                }
                segmentSplit = true;
                morning = morning.add(parseBd(m2.group(1)));
                afternoon = afternoon.add(parseBd(m2.group(2)));
            }

            if (!segmentSplit) {
                java.util.regex.Matcher m1 = one.matcher(segment);
                while (m1.find()) {
                    overtime = overtime.add(parseBd(m1.group(1)));
                }
            }
        }

        return new DeploymentBonusSplit(morning, replaceMorning, afternoon, replaceAfternoon, overtime);
    }

    /** Ghi chú điều động đã duyệt phải có mã đơn [DD:id] hoặc [DDTC:…]. */
    public static boolean isApprovedDeploymentNoteSegment(String segment) {
        if (segment == null || segment.isBlank()) {
            return false;
        }
        String s = segment.trim();
        if (!(s.startsWith("Điều động làm thêm") || s.startsWith("Điều động trong ca"))) {
            return false;
        }
        return s.contains("[DD:") || s.contains("[DDTC:");
    }

    /**
     * Gỡ ghi chú điều động không gắn mã đơn (mồ côi / bản cũ) — giữ dòng đã duyệt.
     */
    public static String dropUnmarkedDeploymentNotes(String existing) {
        if (existing == null || existing.isBlank()) {
            return existing == null ? "" : existing;
        }
        StringBuilder sb = new StringBuilder();
        for (String part : existing.split(";")) {
            String p = part.trim();
            if (p.isEmpty()) {
                continue;
            }
            boolean isDeployment = p.startsWith("Điều động làm thêm") || p.startsWith("Điều động trong ca");
            if (isDeployment && !isApprovedDeploymentNoteSegment(p)) {
                continue;
            }
            if (sb.length() > 0) {
                sb.append("; ");
            }
            sb.append(p);
        }
        return sb.toString();
    }

    private static BigDecimal parseBd(String s) {
        try {
            return new BigDecimal(s);
        } catch (NumberFormatException e) {
            return BigDecimal.ZERO;
        }
    }
}
