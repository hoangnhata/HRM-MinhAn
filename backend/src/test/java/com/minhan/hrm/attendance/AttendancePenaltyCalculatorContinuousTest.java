package com.minhan.hrm.attendance;

import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.AttendanceUpdateKind;
import org.junit.jupiter.api.Test;

import java.time.LocalTime;

import static org.junit.jupiter.api.Assertions.assertEquals;

class AttendancePenaltyCalculatorContinuousTest {

    @Test
    void continuousWithMorningInOnly_countsOneForgotUnit() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .morningCheckIn(LocalTime.of(6, 7))
                .punchTimesJson("[\"06:07:00\",\"06:14:00\"]")
                .build();
        assertEquals(1, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, rec, true));
    }

    @Test
    void continuousWithPunchesOnly_noColumns_stillCountsInAsPresent() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .punchTimesJson("[\"06:07:00\",\"06:14:00\"]")
                .build();
        assertEquals(1, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, rec, true));
    }

    @Test
    void twoPunchAfternoonOutOnly_countsOneMissingMorningIn() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .afternoonCheckOut(LocalTime.of(19, 37))
                .punchTimesJson("[\"19:37:00\"]")
                .build();
        assertEquals(1, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, rec, true));
    }

    @Test
    void twoPunchSameAfternoonTimeOnBothColumns_countsOneMissingMorningIn() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .morningCheckIn(LocalTime.of(19, 37))
                .afternoonCheckOut(LocalTime.of(19, 37))
                .punchTimesJson("[\"19:37:00\"]")
                .build();
        assertEquals(1, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, rec, true));
    }

    @Test
    void twoPunchAfternoonStoredAsMorningIn_countsOneMissingMorningIn() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .morningCheckIn(LocalTime.of(19, 37))
                .punchTimesJson("[\"19:37:00\"]")
                .build();
        assertEquals(1, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, rec, true));
    }

    @Test
    void twoPunchBothPunchesPresent_countsZero() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .morningCheckIn(LocalTime.of(6, 50))
                .afternoonCheckOut(LocalTime.of(17, 5))
                .build();
        assertEquals(0, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, rec, true));
    }

    @Test
    void twoPunchMorningEndPunch_isNotMorningIn_countsTwo() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .punchTimesJson("[\"11:45:00\"]")
                .build();
        AttendanceShiftSchedule schedule = new AttendanceShiftSchedule(
                LocalTime.of(6, 45),
                LocalTime.of(11, 45),
                LocalTime.of(14, 0),
                LocalTime.of(17, 0),
                LocalTime.of(6, 45),
                LocalTime.of(17, 0),
                AttendanceShiftSchedule.MORNING_UNITS,
                AttendanceShiftSchedule.AFTERNOON_UNITS,
                true,
                5,
                3,
                AttendancePunchWindows.defaults());
        assertEquals(2, AttendancePenaltyCalculator.forgotFineUnitsForTwoPunch(rec, schedule));
    }

    @Test
    void twoPunchMorningInInsideWindow_countsOne() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .punchTimesJson("[\"06:50:00\"]")
                .build();
        AttendanceShiftSchedule schedule = new AttendanceShiftSchedule(
                LocalTime.of(6, 45),
                LocalTime.of(11, 45),
                LocalTime.of(14, 0),
                LocalTime.of(17, 0),
                LocalTime.of(6, 45),
                LocalTime.of(17, 0),
                AttendanceShiftSchedule.MORNING_UNITS,
                AttendanceShiftSchedule.AFTERNOON_UNITS,
                true,
                5,
                3,
                AttendancePunchWindows.defaults());
        assertEquals(1, AttendancePenaltyCalculator.forgotFineUnitsForTwoPunch(rec, schedule));
    }

    /** Ca thông tầm 6h45–14h45, chỉ quẹt lúc ra (14:46, 14:47, 14:47) — checkIn = lần quẹt đầu 14:46. */
    @Test
    void continuousOnlyClockOutPunches_firstPunchStoredAsCheckIn_countsOneMissingIn() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .checkIn(LocalTime.of(14, 46))
                .checkOut(LocalTime.of(14, 47))
                .afternoonCheckOut(LocalTime.of(14, 47))
                .punchTimesJson("[\"14:46:00\",\"14:47:00\",\"14:47:00\"]")
                .build();
        assertEquals(1, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, rec, true));
    }

    @Test
    void continuousOnlyMorningPunches_lastPunchStoredAsCheckOut_countsOneMissingOut() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .checkIn(LocalTime.of(6, 40))
                .checkOut(LocalTime.of(6, 42))
                .punchTimesJson("[\"06:40:00\",\"06:42:00\"]")
                .build();
        assertEquals(1, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, rec, true));
    }

    @Test
    void continuousNormalDay_countsZero() {
        AttendanceRecord rec = AttendanceRecord.builder()
                .checkIn(LocalTime.of(6, 40))
                .checkOut(LocalTime.of(14, 50))
                .punchTimesJson("[\"06:40:00\",\"14:50:00\"]")
                .build();
        assertEquals(0, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, rec, true));
    }

    @Test
    void continuousWithNoPunches_countsTwo() {
        assertEquals(2, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, null, true));
    }
}
