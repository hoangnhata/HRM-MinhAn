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

    @BeforeEach
    void setUp() {
        AttendanceShiftScheduleService scheduleService = mock(AttendanceShiftScheduleService.class);
        ContinuousShiftService continuousShiftService = mock(ContinuousShiftService.class);
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

        assertEquals(0, record.getMorningWorkUnits().compareTo(new BigDecimal("1.0")));
        assertEquals("PRESENT", record.getStatus());
        assertEquals("AFTERNOON", record.getForgotShifts());
        assertEquals(LocalTime.of(7, 0), record.getCheckIn());
        assertEquals(LocalTime.of(11, 30), record.getCheckOut());
    }

    @Test
    void insideDeploymentStillCountsLateArrivalAndEarlyDeparture() {
        AttendanceRecord record = record("[\"07:15\",\"11:15\"]", INSIDE_DEPLOYMENT_NOTE);

        processor.applyToRecord(record);

        assertEquals(0, record.getMorningWorkUnits().compareTo(new BigDecimal("1.0")));
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
