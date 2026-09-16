package com.minhan.hrm.service.support;

import java.time.LocalDate;
import java.time.YearMonth;

/** Chuẩn hóa khoảng ngày từ client (tránh lệch cuối tháng do timezone). */
public final class DateRangeSupport {

    private DateRangeSupport() {
    }

    /**
     * Một số client gửi {@code to} thiếu đúng 1 ngày so với cuối tháng khi {@code from} là ngày 1
     * (hay gặp với {@code toISOString()} ở UTC+7). Mở rộng về ngày cuối tháng thực tế.
     */
    public static LocalDate normalizeMonthEndInclusive(LocalDate from, LocalDate to) {
        if (from == null || to == null || from.getDayOfMonth() != 1) {
            return to;
        }
        YearMonth ym = YearMonth.from(from);
        if (!YearMonth.from(to).equals(ym)) {
            return to;
        }
        LocalDate monthEnd = ym.atEndOfMonth();
        if (to.equals(monthEnd.minusDays(1))) {
            return monthEnd;
        }
        return to;
    }
}
