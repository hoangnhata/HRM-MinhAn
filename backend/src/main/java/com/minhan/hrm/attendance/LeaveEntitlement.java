package com.minhan.hrm.attendance;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

/**
 * Hạn mức nghỉ phép năm: 12 ngày cơ bản; cứ đủ 5 năm thâm niên +1 ngày
 * (5 năm → 13, 10 năm → 14, …).
 */
public final class LeaveEntitlement {

    public static final int BASE_DAYS = 12;

    private LeaveEntitlement() {}

    public static int entitlementDays(LocalDate hireDate, LocalDate asOf) {
        if (hireDate == null) {
            return BASE_DAYS;
        }
        LocalDate end = asOf != null ? asOf : LocalDate.now();
        if (end.isBefore(hireDate)) {
            return BASE_DAYS;
        }
        long years = ChronoUnit.YEARS.between(hireDate, end);
        if (years < 0) {
            years = 0;
        }
        return BASE_DAYS + (int) (years / 5);
    }

    public static int yearsOfService(LocalDate hireDate, LocalDate asOf) {
        if (hireDate == null) {
            return 0;
        }
        LocalDate end = asOf != null ? asOf : LocalDate.now();
        if (end.isBefore(hireDate)) {
            return 0;
        }
        return (int) ChronoUnit.YEARS.between(hireDate, end);
    }

    /** Số ngày nghỉ trong khoảng [from, to] inclusive (tính cả cuối tuần). */
    public static int calendarDaysInclusive(LocalDate from, LocalDate to) {
        if (from == null || to == null) {
            return 0;
        }
        if (to.isBefore(from)) {
            return 0;
        }
        return (int) ChronoUnit.DAYS.between(from, to) + 1;
    }
}
