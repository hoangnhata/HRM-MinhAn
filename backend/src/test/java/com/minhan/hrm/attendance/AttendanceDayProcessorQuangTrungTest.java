package com.minhan.hrm.attendance;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.AttendanceShiftScope;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.service.AttendanceService;
import com.minhan.hrm.service.AttendanceShiftScheduleService;
import com.minhan.hrm.service.ContinuousShiftService;
import com.minhan.hrm.service.HolidayWorkDayService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.math.RoundingMode;
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

/** Công Quang Trung không được mất khi đồng bộ máy chấm công ghi đè log giờ chấm. */
class AttendanceDayProcessorQuangTrungTest {

    private static final String QT = AttendanceService.QUANG_TRUNG_NOTE_MARKER + " — không trừ phạt quên chấm";

    private AttendanceDayProcessor processor;

    @BeforeEach
    void setUp() {
        AttendanceShiftScheduleService scheduleService = mock(AttendanceShiftScheduleService.class);
        ContinuousShiftService cs = mock(ContinuousShiftService.class);
        HolidayWorkDayService hs = mock(HolidayWorkDayService.class);
        // Mùa hè: 06:45–11:45 · 14:00–17:00 (như lịch ca của NV báo lỗi)
        AttendanceShiftSchedule schedule = new AttendanceShiftSchedule(
                LocalTime.of(6, 45), LocalTime.of(11, 45), LocalTime.of(14, 0), LocalTime.of(17, 0),
                LocalTime.of(6, 45), LocalTime.of(17, 0),
                AttendanceShiftSchedule.MORNING_UNITS, AttendanceShiftSchedule.AFTERNOON_UNITS,
                true, 5, 3, AttendancePunchWindows.defaults());
        when(scheduleService.forEmployee(anyLong(), any(LocalDate.class))).thenReturn(schedule);
        when(cs.isContinuousShift(anyLong(), any(LocalDate.class))).thenReturn(false);
        when(hs.isHoliday(any(LocalDate.class))).thenReturn(false);
        processor = new AttendanceDayProcessor(new ObjectMapper(), scheduleService, cs, hs);
    }

    /** Giống CheckInOutImportService: ghi đè log giờ chấm bằng dữ liệu máy rồi tính lại ngày. */
    private void simulateSync(AttendanceRecord rec, String machinePunches) {
        rec.setPunchTimesJson(machinePunches);
        rec.setNote(rec.getNote() + "; Đồng bộ máy chấm công");
        processor.applyToRecord(rec);
    }

    private static BigDecimal shift(AttendanceRecord r) {
        return r.getMorningWorkUnits().add(r.getAfternoonWorkUnits()).setScale(2, RoundingMode.HALF_UP);
    }

    private static AttendanceRecord record(String punches, String note) {
        return AttendanceRecord.builder()
                .employee(Employee.builder().id(1L).build())
                .workDate(LocalDate.of(2026, 9, 18))
                .status("ABSENT")
                .morningWorkUnits(BigDecimal.ZERO)
                .afternoonWorkUnits(BigDecimal.ZERO)
                .overtimeWorkUnits(BigDecimal.ZERO)
                .punchTimesJson(punches)
                .note(note)
                .build();
    }

    @Test
    void fullDayQuangTrungSurvivesMachineSync() {
        String marker = AttendanceDayProcessor.quangTrungMarker(AttendanceShiftScope.FULL_DAY, List.of(
                LocalTime.of(6, 10), LocalTime.of(12, 0), LocalTime.of(14, 0), LocalTime.of(17, 0)));
        AttendanceRecord rec = record("[\"06:10\",\"12:00\",\"14:00\",\"17:00\"]", QT + " " + marker);
        processor.applyToRecord(rec);
        assertEquals(new BigDecimal("1.00"), shift(rec));

        // Máy chấm công chỉ có 1 lần quẹt lạc (không ở Quang Trung) → trước đây mất công cả ngày.
        simulateSync(rec, "[\"19:02\"]");

        assertEquals(new BigDecimal("1.00"), shift(rec));
        assertEquals(LocalTime.of(6, 10), rec.getMorningCheckIn());
        assertEquals(LocalTime.of(17, 0), rec.getAfternoonCheckOut());
        assertTrue(rec.getNote().contains("[QT:FULL_DAY=06:10,12:00,14:00,17:00]"));
    }

    @Test
    void morningQuangTrungKeepsMachineAfternoon() {
        String marker = AttendanceDayProcessor.quangTrungMarker(
                AttendanceShiftScope.MORNING, List.of(LocalTime.of(6, 40), LocalTime.of(11, 50)));
        AttendanceRecord rec = record("[\"06:40\",\"11:50\"]", QT + " " + marker);

        // Máy chấm công: sáng ở Quang Trung (không có log), chiều đi làm tại viện.
        simulateSync(rec, "[\"13:55\",\"17:05\"]");

        assertEquals(new BigDecimal("1.00"), shift(rec));
        assertEquals(LocalTime.of(6, 40), rec.getMorningCheckIn());
        assertEquals(LocalTime.of(13, 55), rec.getAfternoonCheckIn());
        assertEquals(LocalTime.of(17, 5), rec.getAfternoonCheckOut());
    }

    @Test
    void legacyQuangTrungWithoutMarkerIsBackfilledBeforeSyncOverwrites() {
        // Bổ sung trước bản sửa: ghi chú chưa có mốc giờ, công đang hiển thị đúng (đã tính từ giờ bổ sung).
        AttendanceRecord rec = record("[\"06:10\",\"12:00\",\"14:00\",\"17:00\"]", QT);
        processor.applyToRecord(rec);
        assertEquals(new BigDecimal("1.00"), shift(rec));

        // Lần đồng bộ kế tiếp: mốc giờ được lưu từ giờ đang có TRƯỚC khi log máy được dùng.
        simulateSync(rec, "[]");

        assertTrue(rec.getNote().contains("[QT:FULL_DAY=06:10,12:00,14:00,17:00]"));
        assertEquals(new BigDecimal("1.00"), shift(rec));

        // Và các lần đồng bộ sau vẫn giữ công.
        simulateSync(rec, "[\"19:02\"]");
        assertEquals(new BigDecimal("1.00"), shift(rec));
    }

    @Test
    void noteWithoutQuangTrungIsUntouched() {
        AttendanceRecord rec = record("[\"06:40\",\"11:50\",\"13:58\",\"17:02\"]", "Đồng bộ máy chấm công");
        processor.applyToRecord(rec);
        assertFalse(rec.getNote().contains("[QT:"));
        assertEquals(new BigDecimal("1.00"), shift(rec));
    }

    @Test
    void stripMarkerKeepsReadableNote() {
        String note = QT + ": Hỗ trợ cơ sở 2 [QT:MORNING=06:40,11:50]";
        assertEquals(QT + ": Hỗ trợ cơ sở 2", AttendanceDayProcessor.stripQuangTrungMarker(note));
    }
}
