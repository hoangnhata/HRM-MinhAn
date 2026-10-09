package com.minhan.hrm.attendance;

import java.time.LocalTime;

/**
 * Tách một khung giờ liên tục trên ngày ca thông tầm thành phần nằm trong ca và phần ngoài ca.
 * Chạm đúng mốc (bắt đầu lúc giờ tan ca) không tính là trong ca.
 */
public final class ContinuousDeploymentSpan {

    public enum Kind {
        INSIDE,
        OUTSIDE,
        MIXED
    }

    public record Result(
            Kind kind,
            LocalTime insideStart,
            LocalTime insideEnd,
            int outsideMinutes) {

        public boolean hasInside() {
            return insideStart != null && insideEnd != null && insideEnd.isAfter(insideStart);
        }

        public double outsideHours() {
            return outsideMinutes / 60.0;
        }
    }

    private ContinuousDeploymentSpan() {
    }

    /**
     * {@code start >= end} (qua đêm hoặc cùng giờ) không tách lẫn — để luồng ngoài ca xử lý.
     */
    public static Result classify(LocalTime start, LocalTime end, LocalTime dayStart, LocalTime dayEnd) {
        if (start == null || end == null || dayStart == null || dayEnd == null
                || !end.isAfter(start) || !dayEnd.isAfter(dayStart)) {
            return new Result(Kind.OUTSIDE, null, null, 0);
        }
        LocalTime insideStart = start.isAfter(dayStart) ? start : dayStart;
        LocalTime insideEnd = end.isBefore(dayEnd) ? end : dayEnd;
        boolean hasInside = insideStart.isBefore(insideEnd);
        int outside = 0;
        if (start.isBefore(dayStart)) {
            LocalTime outEnd = end.isBefore(dayStart) ? end : dayStart;
            outside += minutesBetween(start, outEnd);
        }
        if (end.isAfter(dayEnd)) {
            LocalTime outStart = start.isAfter(dayEnd) ? start : dayEnd;
            outside += minutesBetween(outStart, end);
        }
        if (hasInside && outside > 0) {
            return new Result(Kind.MIXED, insideStart, insideEnd, outside);
        }
        if (hasInside) {
            return new Result(Kind.INSIDE, insideStart, insideEnd, 0);
        }
        return new Result(Kind.OUTSIDE, null, null, outside);
    }

    /**
     * Ca sáng/chiều bình thường: một khung liên tục giao với từng ca,
     * khoảng trước ca, nghỉ trưa và sau ca là ngoài ca.
     */
    public record Windows(
            Kind kind,
            LocalTime morningStart,
            LocalTime morningEnd,
            LocalTime afternoonStart,
            LocalTime afternoonEnd,
            int outsideMinutes) {

        public boolean hasMorning() {
            return morningStart != null && morningEnd != null && morningEnd.isAfter(morningStart);
        }

        public boolean hasAfternoon() {
            return afternoonStart != null && afternoonEnd != null && afternoonEnd.isAfter(afternoonStart);
        }

        public double outsideHours() {
            return outsideMinutes / 60.0;
        }
    }

    public static Windows classifyWindows(
            LocalTime start,
            LocalTime end,
            LocalTime morningStart,
            LocalTime morningEnd,
            LocalTime afternoonStart,
            LocalTime afternoonEnd) {
        if (start == null || end == null || !end.isAfter(start)) {
            return new Windows(Kind.OUTSIDE, null, null, null, null, 0);
        }
        int total = minutesBetween(start, end);
        LocalTime[] morning = clip(start, end, morningStart, morningEnd);
        LocalTime[] afternoon = clip(start, end, afternoonStart, afternoonEnd);
        int inside = 0;
        if (morning != null) {
            inside += minutesBetween(morning[0], morning[1]);
        }
        if (afternoon != null) {
            inside += minutesBetween(afternoon[0], afternoon[1]);
        }
        int outside = Math.max(0, total - inside);
        boolean hasInside = inside > 0;
        Kind kind = hasInside && outside > 0 ? Kind.MIXED : hasInside ? Kind.INSIDE : Kind.OUTSIDE;
        return new Windows(
                kind,
                morning == null ? null : morning[0],
                morning == null ? null : morning[1],
                afternoon == null ? null : afternoon[0],
                afternoon == null ? null : afternoon[1],
                outside);
    }

    private static LocalTime[] clip(LocalTime start, LocalTime end, LocalTime windowStart, LocalTime windowEnd) {
        if (windowStart == null || windowEnd == null || !windowEnd.isAfter(windowStart)) {
            return null;
        }
        LocalTime clipStart = start.isAfter(windowStart) ? start : windowStart;
        LocalTime clipEnd = end.isBefore(windowEnd) ? end : windowEnd;
        if (!clipStart.isBefore(clipEnd)) {
            return null;
        }
        return new LocalTime[] { clipStart, clipEnd };
    }

    private static int minutesBetween(LocalTime start, LocalTime end) {
        if (start == null || end == null || !end.isAfter(start)) {
            return 0;
        }
        return (int) java.time.Duration.between(start, end).toMinutes();
    }
}
