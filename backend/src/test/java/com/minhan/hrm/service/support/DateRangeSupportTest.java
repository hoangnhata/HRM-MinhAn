package com.minhan.hrm.service.support;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;

class DateRangeSupportTest {

    @Test
    void extendsTruncatedAugustEndFromUtcClient() {
        LocalDate from = LocalDate.of(2026, 8, 1);
        LocalDate to = LocalDate.of(2026, 8, 30);
        assertEquals(LocalDate.of(2026, 8, 31), DateRangeSupport.normalizeMonthEndInclusive(from, to));
    }

    @Test
    void leavesCorrectMonthEndUntouched() {
        LocalDate from = LocalDate.of(2026, 8, 1);
        LocalDate to = LocalDate.of(2026, 8, 31);
        assertEquals(to, DateRangeSupport.normalizeMonthEndInclusive(from, to));
    }

    @Test
    void leavesPartialMonthRangeUntouched() {
        LocalDate from = LocalDate.of(2026, 8, 1);
        LocalDate to = LocalDate.of(2026, 8, 15);
        assertEquals(to, DateRangeSupport.normalizeMonthEndInclusive(from, to));
    }

    @Test
    void extendsFebruaryLeapYearEnd() {
        LocalDate from = LocalDate.of(2024, 2, 1);
        LocalDate to = LocalDate.of(2024, 2, 28);
        assertEquals(LocalDate.of(2024, 2, 29), DateRangeSupport.normalizeMonthEndInclusive(from, to));
    }
}
