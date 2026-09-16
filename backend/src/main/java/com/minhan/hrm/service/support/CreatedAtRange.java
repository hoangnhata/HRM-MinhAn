package com.minhan.hrm.service.support;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;

/** Lọc theo ngày gửi (createdAt) theo giờ Việt Nam, inclusive. */
public final class CreatedAtRange {

    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");

    private CreatedAtRange() {}

    public static boolean matches(Instant createdAt, LocalDate fromDate, LocalDate toDate) {
        if (fromDate == null && toDate == null) {
            return true;
        }
        if (createdAt == null) {
            return false;
        }
        LocalDate day = createdAt.atZone(VN).toLocalDate();
        if (fromDate != null && day.isBefore(fromDate)) {
            return false;
        }
        if (toDate != null && day.isAfter(toDate)) {
            return false;
        }
        return true;
    }

    /** createdAt ISO / date string từ map API. */
    public static boolean matchesRaw(Object createdAt, LocalDate fromDate, LocalDate toDate) {
        if (fromDate == null && toDate == null) {
            return true;
        }
        if (createdAt == null) {
            return false;
        }
        String raw = String.valueOf(createdAt).trim();
        if (raw.isEmpty()) {
            return false;
        }
        LocalDate day;
        try {
            if (raw.length() >= 10 && raw.charAt(4) == '-') {
                day = LocalDate.parse(raw.substring(0, 10));
            } else {
                day = Instant.parse(raw).atZone(VN).toLocalDate();
            }
        } catch (Exception e) {
            return false;
        }
        if (fromDate != null && day.isBefore(fromDate)) {
            return false;
        }
        if (toDate != null && day.isAfter(toDate)) {
            return false;
        }
        return true;
    }
}
