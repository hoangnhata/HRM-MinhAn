package com.minhan.hrm.attendance;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

/**
 * Hạn mức nghỉ phép năm: 12 ngày cơ bản; cứ đủ 5 năm thâm niên +1 ngày
 * (5 năm → 13, 10 năm → 14, …).
 */
public final class LeaveEntitlement {

    public static final int BASE_DAYS = 12;
    /** Trần công tháng để còn được xin nghỉ phép (công chấm + phép + trực, không gồm điều động). */
    public static final BigDecimal MONTHLY_WORK_CAP_EXCLUDING_DEPLOYMENT = new BigDecimal("27");

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

    /** Số ngày giao nhau giữa [from, to] và [rangeStart, rangeEnd], inclusive. */
    public static int overlapDays(LocalDate from, LocalDate to, LocalDate rangeStart, LocalDate rangeEnd) {
        if (from == null || to == null || rangeStart == null || rangeEnd == null) {
            return 0;
        }
        LocalDate a = from.isBefore(rangeStart) ? rangeStart : from;
        LocalDate b = to.isAfter(rangeEnd) ? rangeEnd : to;
        return calendarDaysInclusive(a, b);
    }

    /**
     * Vượt trần 27 công/tháng khi cộng thêm {@code extraDays} vào công đã có
     * (chấm + phép + trực, chưa gồm điều động).
     */
    public static boolean exceedsMonthlyWorkCap(BigDecimal recordedWork, int extraDays) {
        BigDecimal current = recordedWork != null ? recordedWork : BigDecimal.ZERO;
        BigDecimal total = current.add(BigDecimal.valueOf(Math.max(0, extraDays)));
        return total.compareTo(MONTHLY_WORK_CAP_EXCLUDING_DEPLOYMENT) > 0;
    }
}
