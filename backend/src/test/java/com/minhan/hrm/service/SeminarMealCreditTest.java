package com.minhan.hrm.service;

import com.minhan.hrm.entity.AttendanceRecord;
import org.junit.jupiter.api.Test;

import java.time.LocalTime;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SeminarMealCreditTest {

    @Test
    void morningPunchOnFullDaySeminar_keepsMorningMeal() {
        AttendanceRecord record = AttendanceRecord.builder()
                .status("SEMINAR")
                .morningCheckIn(LocalTime.of(6, 45))
                .morningCheckOut(LocalTime.of(11, 53))
                .build();

        assertEquals(
                AttendanceSummaryService.SeminarMealCredit.MORNING,
                AttendanceSummaryService.seminarMealCredit(record));
    }

    @Test
    void seminarWithoutPunch_hasNoMeal() {
        AttendanceRecord record = AttendanceRecord.builder()
                .status("SEMINAR")
                .build();

        assertEquals(
                AttendanceSummaryService.SeminarMealCredit.NONE,
                AttendanceSummaryService.seminarMealCredit(record));
    }

    @Test
    void bothShiftsPunched_countsFullMeal() {
        AttendanceRecord record = AttendanceRecord.builder()
                .status("SEMINAR")
                .morningCheckIn(LocalTime.of(6, 45))
                .afternoonCheckOut(LocalTime.of(17, 0))
                .build();

        assertEquals(
                AttendanceSummaryService.SeminarMealCredit.FULL,
                AttendanceSummaryService.seminarMealCredit(record));
    }
}
