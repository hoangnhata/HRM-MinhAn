package com.minhan.hrm.attendance;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class LeaveEntitlementTest {

    @Test
    void allowsLeaveUntilExactlyTwentySevenWorkUnits() {
        assertFalse(LeaveEntitlement.exceedsMonthlyWorkCap(new BigDecimal("26"), 1));
        assertTrue(LeaveEntitlement.exceedsMonthlyWorkCap(new BigDecimal("26"), 2));
        assertTrue(LeaveEntitlement.exceedsMonthlyWorkCap(new BigDecimal("27"), 1));
        assertFalse(LeaveEntitlement.exceedsMonthlyWorkCap(new BigDecimal("27"), 0));
        assertTrue(LeaveEntitlement.exceedsMonthlyWorkCap(new BigDecimal("27.50"), 1));
    }

    @Test
    void overlapDaysClipsToMonth() {
        LocalDate from = LocalDate.of(2026, 8, 30);
        LocalDate to = LocalDate.of(2026, 9, 2);
        assertEquals(2, LeaveEntitlement.overlapDays(
                from, to, LocalDate.of(2026, 8, 1), LocalDate.of(2026, 8, 31)));
        assertEquals(2, LeaveEntitlement.overlapDays(
                from, to, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 30)));
    }
}
