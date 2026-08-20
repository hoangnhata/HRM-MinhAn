package com.minhan.hrm.attendance;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.AttendanceShiftScope;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.service.AttendanceShiftScheduleService;
import com.minhan.hrm.service.ContinuousShiftService;
import com.minhan.hrm.service.HolidayWorkDayService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Ca sáng 6:45–11:45, chiều 14:00–17:00 — giờ ra sáng trễ (11:48) phải thuộc sáng.
 */
class AttendanceDayProcessorMorningOutTest {

    private static final LocalDate WORK_DATE = LocalDate.of(2026, 8, 3);

    private AttendanceDayProcessor processor;
    private AttendanceShiftSchedule schedule;

    @BeforeEach
    void setUp() {
        AttendanceShiftScheduleService scheduleService = mock(AttendanceShiftScheduleService.class);
        ContinuousShiftService continuousShiftService = mock(ContinuousShiftService.class);
        HolidayWorkDayService holidayWorkDayService = mock(HolidayWorkDayService.class);
        schedule = new AttendanceShiftSchedule(
                LocalTime.of(6, 45),
                LocalTime.of(11, 45),
                LocalTime.of(14, 0),
                LocalTime.of(17, 0),
                LocalTime.of(6, 45),
                LocalTime.of(17, 0),
                AttendanceShiftSchedule.MORNING_UNITS,
                AttendanceShiftSchedule.AFTERNOON_UNITS,
                true,
                5.0,
                3.0,
                AttendancePunchWindows.defaults());

        when(scheduleService.forEmployee(anyLong(), any(LocalDate.class))).thenReturn(schedule);
        when(continuousShiftService.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(false);
        when(holidayWorkDayService.isHoliday(any(LocalDate.class))).thenReturn(false);
        processor = new AttendanceDayProcessor(
                new ObjectMapper(), scheduleService, continuousShiftService, holidayWorkDayService);
    }

    @Test
    void lateMorningOutStillCountsAsMorningPunch() {
        assertTrue(AttendanceDayProcessor.isMorningPunch(LocalTime.of(11, 48), schedule));
        assertTrue(AttendanceDayProcessor.isMorningPunch(LocalTime.of(6, 43), schedule));
        assertFalse(AttendanceDayProcessor.isMorningPunch(LocalTime.of(13, 11), schedule));
        assertFalse(AttendanceDayProcessor.isMorningPunch(LocalTime.of(17, 0), schedule));
    }

    @Test
    void devicePunchesCreditMorningWhenOutIsFewMinutesLate() {
        AttendanceRecord record = record("[\"06:43\",\"06:44\",\"11:48\",\"13:11\",\"17:00\"]");

        processor.applyToRecord(record);

        assertEquals(LocalTime.of(6, 43), record.getMorningCheckIn());
        assertEquals(LocalTime.of(11, 48), record.getMorningCheckOut());
        assertEquals(LocalTime.of(13, 11), record.getAfternoonCheckIn());
        assertEquals(LocalTime.of(17, 0), record.getAfternoonCheckOut());
        assertTrue(record.getMorningWorkUnits().compareTo(BigDecimal.ZERO) > 0);
        assertTrue(record.getAfternoonWorkUnits().compareTo(BigDecimal.ZERO) > 0);
    }

    @Test
    void afternoonManualUpdateDoesNotWipeLateMorningOut() {
        AttendanceRecord record = record("[\"06:43\",\"06:44\",\"11:48\",\"13:11\"]");

        processor.applyManualShift(
                record,
                AttendanceShiftScope.AFTERNOON,
                LocalTime.of(13, 11),
                LocalTime.of(17, 0));

        List<LocalTime> punches = processor.resolvePunches(record);
        assertTrue(punches.contains(LocalTime.of(11, 48)), "Giờ ra sáng 11:48 không được xóa khi cập nhật ca chiều");
        assertTrue(punches.contains(LocalTime.of(6, 43)));
        assertEquals(LocalTime.of(11, 48), record.getMorningCheckOut());
        assertEquals(LocalTime.of(17, 0), record.getAfternoonCheckOut());
    }

    private static AttendanceRecord record(String punches) {
        return AttendanceRecord.builder()
                .employee(Employee.builder().id(204L).build())
                .workDate(WORK_DATE)
                .status("ABSENT")
                .morningWorkUnits(BigDecimal.ZERO)
                .afternoonWorkUnits(BigDecimal.ZERO)
                .overtimeWorkUnits(BigDecimal.ZERO)
                .punchTimesJson(punches)
                .note("Đồng bộ máy chấm công")
                .build();
    }
}
