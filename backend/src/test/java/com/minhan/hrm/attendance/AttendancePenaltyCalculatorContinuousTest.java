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
    void continuousWithNoPunches_countsTwo() {
        assertEquals(2, AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                AttendanceUpdateKind.FULL_DAY_SUPPLEMENT, null, true));
    }
}
