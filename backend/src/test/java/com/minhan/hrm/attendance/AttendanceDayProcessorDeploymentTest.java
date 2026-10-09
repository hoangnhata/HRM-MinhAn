package com.minhan.hrm.attendance;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.service.AttendanceShiftScheduleService;
import com.minhan.hrm.service.ContinuousShiftService;
import com.minhan.hrm.service.HolidayWorkDayService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class AttendanceDayProcessorDeploymentTest {

    private static final LocalDate WORK_DATE = LocalDate.of(2026, 7, 30);
    private static final String INSIDE_DEPLOYMENT_NOTE =
            "Điều động trong ca ×1.5: Ca sáng 07:00–11:30 — chờ đủ giờ vào/ra "
                    + "(=1.0 sáng / =0 chiều / +0 ngoài giờ) [DDTC:S=07:00-11:30;A=-]";

    private AttendanceDayProcessor processor;
    private ContinuousShiftService continuousShiftService;

    @BeforeEach
    void setUp() {
        AttendanceShiftScheduleService scheduleService = mock(AttendanceShiftScheduleService.class);
        continuousShiftService = mock(ContinuousShiftService.class);
        HolidayWorkDayService holidayWorkDayService = mock(HolidayWorkDayService.class);
        AttendanceShiftSchedule schedule = new AttendanceShiftSchedule(
                LocalTime.of(7, 0),
                LocalTime.of(11, 30),
                LocalTime.of(13, 30),
                LocalTime.of(17, 0),
                LocalTime.of(7, 0),
                LocalTime.of(17, 0),
                AttendanceShiftSchedule.MORNING_UNITS,
                AttendanceShiftSchedule.AFTERNOON_UNITS,
                true,
                4.5,
                3.5,
                AttendancePunchWindows.defaults());

        when(scheduleService.forEmployee(anyLong(), any(LocalDate.class))).thenReturn(schedule);
        when(continuousShiftService.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(false);
        when(holidayWorkDayService.isHoliday(any(LocalDate.class))).thenReturn(false);
        processor = new AttendanceDayProcessor(
                new ObjectMapper(), scheduleService, continuousShiftService, holidayWorkDayService);
    }

    @Test
    void approvedInsideDeploymentDoesNotCreditWorkWithoutPunches() {
        AttendanceRecord record = record("[]", INSIDE_DEPLOYMENT_NOTE);

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals("ABSENT", record.getStatus());
        assertEquals("MORNING", record.getForgotShifts());
        assertNull(record.getCheckIn());
        assertNull(record.getCheckOut());
    }

    @Test
    void missingAfternoonDeploymentPunchesFlagsAfternoonForWorkUpdateRequest() {
        AttendanceRecord record = record(
                "[]",
                "Điều động trong ca ×1.5: Ca chiều 13:30–17:00 — chờ đủ giờ vào/ra "
                        + "(=0 sáng / =0.5 chiều / +0 ngoài giờ) [DDTC:S=-;A=13:30-17:00]");

        processor.applyToRecord(record);

        assertEquals(0, record.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO));
        assertTrue(record.getForgotShifts().contains("AFTERNOON"));
    }

    @Test
    void approvedInsideDeploymentCreditsWorkAfterMatchingInAndOutPunches() {
        AttendanceRecord record = record("[\"07:00\",\"11:30\"]", INSIDE_DEPLOYMENT_NOTE);

        processor.applyToRecord(record);

        assertUnits("0.67", record.getMorningWorkUnits());
        assertUnits("0.33", record.getOvertimeWorkUnits());
        assertUnits("1.00", totalUnits(record));
        assertEquals("PRESENT", record.getStatus());
        assertEquals("AFTERNOON", record.getForgotShifts());
        assertEquals(LocalTime.of(7, 0), record.getCheckIn());
        assertEquals(LocalTime.of(11, 30), record.getCheckOut());
    }

    @Test
    void insideDeploymentStillCountsLateArrivalAndEarlyDeparture() {
        AttendanceRecord record = record("[\"07:15\",\"11:15\"]", INSIDE_DEPLOYMENT_NOTE);

        processor.applyToRecord(record);

        assertUnits("0.67", record.getMorningWorkUnits());
        assertUnits("0.33", record.getOvertimeWorkUnits());
        assertEquals(30, record.getLateMinutes());
    }

    @Test
    void unmarkedDeploymentNoteDoesNotCreditOvertime() {
        AttendanceRecord record = record(
                "[]",
                "Điều động làm thêm ×1.5: 17:00–19:00 "
                        + "(+0 sáng / +0 chiều / +0.38 ngoài giờ)");

        processor.applyToRecord(record);

        assertEquals(0, record.getOvertimeWorkUnits().compareTo(BigDecimal.ZERO));
        assertTrue(record.getNote() == null || record.getNote().isBlank());
    }

    @Test
    void approvedDeploymentNoteWithIdCreditsOvertime() {
        AttendanceRecord record = record(
                "[]",
                "Điều động làm thêm ×1.5: 17:00–19:00 "
                        + "(+0 sáng / +0 chiều / +0.38 ngoài giờ) [DD:54]");

        processor.applyToRecord(record);

        assertEquals(0, record.getOvertimeWorkUnits().compareTo(new BigDecimal("0.38")));
        assertEquals("PARTIAL", record.getStatus());
    }

    @Test
    void duplicateUnmarkedDeploymentIsIgnoredWhenApprovedExists() {
        AttendanceRecord record = record(
                "[\"06:19\",\"12:07\",\"13:53\",\"17:19\"]",
                "Đồng bộ máy chấm công; "
                        + "Điều động làm thêm ×1.5: 06:20–06:45 · 0.42h → 0.63h công "
                        + "(+0 sáng / +0 chiều / +0.08 ngoài giờ): Xử lý máy bơm; "
                        + "Điều động làm thêm ×1.5: 06:20–06:45 · 0.42h → 0.63h công "
                        + "(+0 sáng / +0 chiều / +0.08 ngoài giờ): Xử lý máy bơm [DD:54]; "
                        + "Điều động làm thêm ×1.5: 18:00–21:00 · 3.00h → 4.50h công "
                        + "(+0 sáng / +0 chiều / +0.56 ngoài giờ): Dồn dịch TNT [DD:194]");

        processor.applyToRecord(record);

        // Chỉ 0.08 + 0.56 từ hai đơn đã duyệt — bỏ bản mồ côi không mã
        assertEquals(0, record.getOvertimeWorkUnits().compareTo(new BigDecimal("0.64")));
        assertTrue(record.getNote() != null && record.getNote().contains("[DD:54]"));
        assertTrue(record.getNote().contains("[DD:194]"));
        assertTrue(record.getNote().contains("Đồng bộ máy chấm công"));
    }

    @Test
    void paidMorningSeminarKeepsAfternoonWorkFromPunches() {
        AttendanceRecord record = record(
                "[\"13:30\",\"17:00\"]",
                "Hội thảo đã duyệt (có công, ca sáng) [SEMINAR:MORNING:PAID]");

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(AttendanceShiftSchedule.MORNING_UNITS));
        assertEquals(0, record.getAfternoonWorkUnits().compareTo(AttendanceShiftSchedule.AFTERNOON_UNITS));
        assertEquals("SEMINAR", record.getStatus());
        assertNull(record.getForgotShifts());
    }

    @Test
    void paidMorningSeminarDoesNotCreditAfternoonWithoutPunches() {
        AttendanceRecord record = record(
                "[]",
                "Hội thảo đã duyệt (có công, ca sáng) [SEMINAR:MORNING:PAID]");

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(AttendanceShiftSchedule.MORNING_UNITS));
        assertEquals(0, record.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals("SEMINAR", record.getStatus());
    }

    @Test
    void unpaidFullDaySeminarKeepsMorningWorkFromActualPunches() {
        // Hội thảo không công cả ngày nhưng vẫn đi làm ca sáng (log 6:18–11:46).
        AttendanceRecord record = record(
                "[\"06:18\",\"11:46\"]",
                "Hội thảo đã duyệt (không công, cả ngày) [SEMINAR:FULL_DAY:UNPAID]: "
                        + "Hội nghị đau toàn quốc lần IV năm 2026 tại Thành Phố Huế");

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(AttendanceShiftSchedule.MORNING_UNITS));
        assertEquals(0, record.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals("SEMINAR", record.getStatus());
        assertNull(record.getForgotShifts());
        assertEquals(LocalTime.of(6, 18), record.getMorningCheckIn());
        assertEquals(LocalTime.of(11, 46), record.getMorningCheckOut());
    }

    @Test
    void unpaidFullDaySeminarWithoutPunchesStaysZeroWork() {
        AttendanceRecord record = record(
                "[]",
                "Hội thảo đã duyệt (không công, cả ngày) [SEMINAR:FULL_DAY:UNPAID]");

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals(0, record.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals("SEMINAR", record.getStatus());
    }

    @Test
    void strippingDeploymentNoteClearsLeftoverOvertimeUnits() {
        AttendanceRecord record = record(
                "[\"06:54\"]",
                "Điều động làm thêm ×1.5: 18:00–21:00 · 3.00h → 4.50h công (+0 sáng / +0 chiều / +0.56 ngoài giờ) [DD:194]");
        record.setOvertimeWorkUnits(new BigDecimal("0.56"));
        record.setMorningWorkUnits(new BigDecimal("0.23"));
        record.setStatus("PARTIAL");

        // Giả lập revoke: bỏ ghi chú điều động rồi tính lại
        record.setNote("");
        processor.applyToRecord(record);

        assertEquals(0, record.getOvertimeWorkUnits().compareTo(BigDecimal.ZERO));
    }

    @Test
    void fourApprovedOvertimeDeploymentsStillSumWhenNoteExceedsLegacy500Chars() {
        String note = String.join("; ",
                "Điều động làm thêm ×1.5: 17:00–17:50 · 0.83h → 1.25h công (+0 sáng / +0 chiều / +0.16 ngoài giờ): Thêm nhân tạo [DD:580]",
                "Điều động làm thêm ×1.5: 11:45–13:30 · 1.75h → 2.63h công (+0 sáng / +0 chiều / +0.33 ngoài giờ): Thêm nhân tạo [DD:573]",
                "Điều động làm thêm ×1.5: 13:30–14:00 · 0.50h → 0.75h công (+0 sáng / +0 chiều / +0.09 ngoài giờ): Thêm nhân tạo [DD:568]",
                "Điều động làm thêm ×1.5: 05:30–06:45 · 1.25h → 1.88h công (+0 sáng / +0 chiều / +0.23 ngoài giờ): Thêm nhân tạo [DD:999]",
                "Đồng bộ máy chấm công");
        assertTrue(note.length() > 500);

        AttendanceRecord record = record("[\"05:17\",\"11:59\",\"13:36\",\"17:56\"]", note);
        processor.applyToRecord(record);

        assertUnits("0.81", record.getOvertimeWorkUnits());
    }

    @Test
    void continuousInsideDeploymentCreditsFullDayAfterInAndOutPunches() {
        when(continuousShiftService.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(true);
        AttendanceRecord record = record(
                "[\"07:00\",\"17:00\"]",
                "Điều động trong ca thông tầm ×1.5: Ca thông tầm 07:00–17:00 — chờ đủ giờ vào/ra "
                        + "(=1.0 sáng / =0.5 chiều / +0 ngoài giờ) [DDTC:S=07:00-17:00;A=-]");

        processor.applyToRecord(record);

        assertUnits("1.00", shiftUnits(record));
        assertUnits("0.50", record.getOvertimeWorkUnits());
        assertUnits("1.50", totalUnits(record));
        assertEquals("PRESENT", record.getStatus());
        assertNull(record.getForgotShifts());
        assertEquals(LocalTime.of(7, 0), record.getCheckIn());
        assertEquals(LocalTime.of(17, 0), record.getCheckOut());
    }

    @Test
    void continuousInsideDeploymentDoesNotCreditWithoutBothPunches() {
        when(continuousShiftService.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(true);
        AttendanceRecord record = record(
                "[\"07:00\"]",
                "Điều động trong ca thông tầm ×1.5: Ca thông tầm 07:00–17:00 — chờ đủ giờ vào/ra "
                        + "(=1.0 sáng / =0.5 chiều / +0 ngoài giờ) [DDTC:S=07:00-17:00;A=-]");

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals(0, record.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO));
        assertTrue(record.getForgotShifts() != null && record.getForgotShifts().contains("AFTERNOON"));
    }

    /** Ca thông tầm 05:30–13:30 (đúng như ca của nhân viên báo lỗi). */
    private AttendanceDayProcessor earlyContinuousProcessor() {
        return earlyContinuousProcessor(false);
    }

    private AttendanceDayProcessor earlyContinuousProcessor(boolean holiday) {
        AttendanceShiftScheduleService scheduleService = mock(AttendanceShiftScheduleService.class);
        ContinuousShiftService cs = mock(ContinuousShiftService.class);
        HolidayWorkDayService hs = mock(HolidayWorkDayService.class);
        AttendanceShiftSchedule schedule = new AttendanceShiftSchedule(
                LocalTime.of(7, 0), LocalTime.of(11, 30), LocalTime.of(13, 30), LocalTime.of(17, 0),
                LocalTime.of(5, 30), LocalTime.of(13, 30),
                AttendanceShiftSchedule.MORNING_UNITS, AttendanceShiftSchedule.AFTERNOON_UNITS,
                true, 4.5, 3.5, AttendancePunchWindows.defaults());
        when(scheduleService.forEmployee(anyLong(), any(LocalDate.class))).thenReturn(schedule);
        when(cs.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(true);
        when(hs.isHoliday(any(LocalDate.class))).thenReturn(holiday);
        return new AttendanceDayProcessor(new ObjectMapper(), scheduleService, cs, hs);
    }

    /** Ngày lễ: công chấm nhân đôi; phần điều động trong ca cũng nhân đôi (tổng như trước: 1,5 × 2). */
    @Test
    void holidayInShiftDeploymentKeepsDoubledTotalButSplitsShiftAndDeployment() {
        AttendanceRecord record = record(
                "[\"05:28\",\"13:35\"]",
                "Điều động trong ca thông tầm ×1.5: Ca thông tầm 05:30–13:30 — chờ đủ giờ vào/ra "
                        + "(=1.0 sáng / =0.5 chiều / +0 ngoài giờ) [DDTC:S=05:30-13:30;A=-] [DD:9]");

        earlyContinuousProcessor(true).applyToRecord(record);

        assertUnits("2.00", shiftUnits(record));
        assertUnits("1.00", record.getOvertimeWorkUnits());
        assertUnits("3.00", totalUnits(record));
    }

    private static BigDecimal shiftUnits(AttendanceRecord r) {
        return r.getMorningWorkUnits().add(r.getAfternoonWorkUnits());
    }

    private static BigDecimal totalUnits(AttendanceRecord r) {
        return shiftUnits(r).add(r.getOvertimeWorkUnits());
    }

    private static void assertUnits(String expected, BigDecimal actual) {
        assertEquals(new BigDecimal(expected), actual.setScale(2, java.math.RoundingMode.HALF_UP));
    }

    /** 19/9: điều động 12:30–17:45 cắt cuối ca → trong ca 12:30–13:30 + ngoài ca 4,25h. */
    @Test
    void continuousPartialDeploymentAtShiftEndKeepsRegularShiftPunches() {
        AttendanceRecord record = record(
                "[\"05:30:10\",\"13:38:39\",\"17:46:33\"]",
                "Điều động trong ca và ngoài ca thông tầm ×1.5: 12:30–17:45 (trong ca 12:30–13:30 · ngoài ca 4.25h) "
                        + "— chờ đủ giờ vào/ra trong ca (=0.13 sáng / =0.06 chiều / +0.80 ngoài giờ) "
                        + "[DDTC:S=12:30-13:30;A=-] [DD:1]");

        earlyContinuousProcessor().applyToRecord(record);

        assertEquals(LocalTime.of(5, 30, 10), record.getMorningCheckIn());
        assertEquals(LocalTime.of(13, 38, 39), record.getAfternoonCheckOut());
        assertNull(record.getForgotShifts());
        // Công chấm = 1 ngày; công điều động = ngoài ca 0,80 + phần ×1,5 của 1h trong ca (0,19 / 3)
        assertUnits("1.00", shiftUnits(record));
        assertUnits("0.86", record.getOvertimeWorkUnits());
        assertEquals("PRESENT", record.getStatus());
    }

    /** 23/9: điều động trong ca đầu ca 05:30–07:00 + điều động làm thêm sau ca. */
    @Test
    void continuousPartialDeploymentAtShiftStartKeepsRegularShiftPunches() {
        AttendanceRecord record = record(
                "[\"05:22:02\",\"05:22:40\",\"11:49:13\",\"13:29:54\",\"18:03:10\"]",
                "Điều động trong ca thông tầm ×1.5: Ca thông tầm 05:30–07:00 — chờ đủ giờ vào/ra "
                        + "(=0.19 sáng / =0.09 chiều / +0 ngoài giờ) [DDTC:S=05:30-07:00;A=-] [DD:2349]; "
                        + "Điều động làm thêm ×1.5: 16:40–18:03 · 1.40h → 2.10h công "
                        + "(+0 sáng / +0 chiều / +0.26 ngoài giờ) [DD:2350]");

        earlyContinuousProcessor().applyToRecord(record);

        assertEquals(LocalTime.of(5, 22, 2), record.getMorningCheckIn());
        assertEquals(LocalTime.of(13, 29, 54), record.getAfternoonCheckOut());
        assertNull(record.getForgotShifts());
        assertUnits("1.00", shiftUnits(record));
        assertUnits("0.35", record.getOvertimeWorkUnits());
    }

    /** Chỉ làm đúng khung điều động (không đủ giờ ca) → vẫn tính công theo khung như trước. */
    @Test
    void continuousDeploymentOnlyWindowWorkedFallsBackToDeploymentWindow() {
        AttendanceRecord record = record(
                "[\"09:00\",\"11:00\"]",
                "Điều động trong ca thông tầm ×1.5: Ca thông tầm 09:00–11:00 — chờ đủ giờ vào/ra "
                        + "(=0.25 sáng / =0.13 chiều / +0 ngoài giờ) [DDTC:S=09:00-11:00;A=-] [DD:7]");

        earlyContinuousProcessor().applyToRecord(record);

        assertEquals(LocalTime.of(9, 0), record.getMorningCheckIn());
        assertEquals(LocalTime.of(11, 0), record.getAfternoonCheckOut());
        assertUnits("0.25", shiftUnits(record));
        assertUnits("0.13", record.getOvertimeWorkUnits());
        assertUnits("0.38", totalUnits(record));
    }

    /** Thiếu giờ ra của ca và không khớp khung điều động → không công ca, vẫn giữ ngoài giờ đã duyệt. */
    @Test
    void continuousPartialDeploymentWithoutShiftOutKeepsOvertimeOnly() {
        AttendanceRecord record = record(
                "[\"05:30\"]",
                "Điều động trong ca và ngoài ca thông tầm ×1.5: 12:30–17:45 — chờ đủ giờ vào/ra trong ca "
                        + "(=0.13 sáng / =0.06 chiều / +0.80 ngoài giờ) [DDTC:S=12:30-13:30;A=-] [DD:1]");

        earlyContinuousProcessor().applyToRecord(record);

        assertEquals(0, shiftUnits(record).compareTo(BigDecimal.ZERO));
        assertEquals(0, record.getOvertimeWorkUnits().compareTo(new BigDecimal("0.80")));
        assertTrue(record.getForgotShifts().contains("AFTERNOON"));
    }

    @Test
    void twoPunchAttendanceCreditsFullDayWithMorningInAndAfternoonOutOnly() {
        when(continuousShiftService.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(false);
        when(continuousShiftService.isTwoPunchAttendance(anyLong(), any(LocalDate.class))).thenReturn(true);
        AttendanceRecord record = record("[\"07:05\",\"17:02\"]", null);

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(AttendanceShiftSchedule.MORNING_UNITS));
        assertEquals(0, record.getAfternoonWorkUnits().compareTo(AttendanceShiftSchedule.AFTERNOON_UNITS));
        assertEquals("PRESENT", record.getStatus());
        assertNull(record.getForgotShifts());
        assertEquals(LocalTime.of(7, 5), record.getMorningCheckIn());
        assertNull(record.getMorningCheckOut());
        assertNull(record.getAfternoonCheckIn());
        assertEquals(LocalTime.of(17, 2), record.getAfternoonCheckOut());
    }

    @Test
    void twoPunchAttendanceFlagsMissingAfternoonOut() {
        when(continuousShiftService.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(false);
        when(continuousShiftService.isTwoPunchAttendance(anyLong(), any(LocalDate.class))).thenReturn(true);
        AttendanceRecord record = record("[\"07:00\"]", null);

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals(0, record.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO));
        assertTrue(record.getForgotShifts() != null && record.getForgotShifts().contains("AFTERNOON"));
        assertTrue(!record.getForgotShifts().contains("MORNING"));
    }

    @Test
    void twoPunchAttendanceDoesNotCreditMorningWhenLateOrphanPunchIsNotAfternoonOut() {
        when(continuousShiftService.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(false);
        when(continuousShiftService.isTwoPunchAttendance(anyLong(), any(LocalDate.class))).thenReturn(true);
        AttendanceRecord record = record("[\"07:03\",\"21:24\"]", null);
        record.setWorkDate(LocalDate.of(2026, 9, 6));

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals(0, record.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals(LocalTime.of(7, 3), record.getMorningCheckIn());
        assertNull(record.getAfternoonCheckOut());
        assertTrue(record.getForgotShifts() != null && record.getForgotShifts().contains("AFTERNOON"));
        assertEquals("ABSENT", record.getStatus());
    }

    @Test
    void splitDayForTwoPunchAccountCreditsMorningWhenAfternoonOutWindowMisses() {
        AttendanceDayProcessor splitProcessor = splitScLeaderProcessor();
        AttendanceRecord rec = record("[\"06:26\",\"13:39\"]", null);
        rec.setWorkDate(LocalDate.of(2026, 9, 13));

        splitProcessor.applyToRecord(rec);

        assertEquals(LocalTime.of(6, 26), rec.getMorningCheckIn());
        assertEquals(LocalTime.of(13, 39), rec.getMorningCheckOut());
        assertNull(rec.getAfternoonCheckIn());
        assertNull(rec.getAfternoonCheckOut());
        assertEquals(0, rec.getMorningWorkUnits().compareTo(AttendanceShiftSchedule.MORNING_UNITS));
        assertEquals(0, rec.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO));
        assertEquals("PARTIAL", rec.getStatus());
        assertTrue(rec.getForgotShifts() != null && rec.getForgotShifts().contains("AFTERNOON"));
    }

    /** Ca SC lãnh đạo: 06:45–11:45 / 14:00–17:00, ra sáng sau 120 phút — ngày SPLIT tắt PQ 2 mốc. */
    private AttendanceDayProcessor splitScLeaderProcessor() {
        AttendanceShiftScheduleService scheduleService = mock(AttendanceShiftScheduleService.class);
        ContinuousShiftService cs = mock(ContinuousShiftService.class);
        HolidayWorkDayService hs = mock(HolidayWorkDayService.class);
        AttendancePunchWindows windows = new AttendancePunchWindows(60, 120, 60, 120, 15, 60, 60, 60);
        AttendanceShiftSchedule schedule = new AttendanceShiftSchedule(
                LocalTime.of(6, 45), LocalTime.of(11, 45), LocalTime.of(14, 0), LocalTime.of(17, 0),
                LocalTime.of(6, 45), LocalTime.of(17, 0),
                AttendanceShiftSchedule.MORNING_UNITS, AttendanceShiftSchedule.AFTERNOON_UNITS,
                true, 5, 3, windows);
        when(scheduleService.forEmployee(anyLong(), any(LocalDate.class))).thenReturn(schedule);
        when(cs.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(false);
        when(cs.isTwoPunchAttendance(anyLong(), any(LocalDate.class))).thenReturn(false);
        when(hs.isHoliday(any(LocalDate.class))).thenReturn(false);
        return new AttendanceDayProcessor(new ObjectMapper(), scheduleService, cs, hs);
    }

    private static AttendanceRecord record(String punches, String note) {
        return AttendanceRecord.builder()
                .employee(Employee.builder().id(1L).build())
                .workDate(WORK_DATE)
                .status("ABSENT")
                .morningWorkUnits(BigDecimal.ZERO)
                .afternoonWorkUnits(BigDecimal.ZERO)
                .overtimeWorkUnits(BigDecimal.ZERO)
                .punchTimesJson(punches)
                .note(note)
                .build();
    }
}
