package com.minhan.hrm.attendance;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Ca sáng {@code 2/3} công, ca chiều {@code 1/3} công (tổng đúng 1).
 * <p>
 * Giờ ca lấy từ {@link com.minhan.hrm.service.AttendanceShiftScheduleService} (admin cấu hình).
 */
public record AttendanceShiftSchedule(
        LocalTime morningStart,
        LocalTime morningEnd,
        LocalTime afternoonStart,
        LocalTime afternoonEnd,
        LocalTime continuousStart,
        LocalTime continuousEnd,
        BigDecimal morningUnits,
        BigDecimal afternoonUnits,
        boolean summer,
        double morningHours,
        double afternoonHours,
        AttendancePunchWindows punchWindows) {

    /** 2/3 — scale 8; chiều = 1 − sáng để tổng luôn đúng 1. */
    public static final BigDecimal MORNING_UNITS =
            new BigDecimal("2").divide(new BigDecimal("3"), 8, RoundingMode.HALF_UP);
    public static final BigDecimal AFTERNOON_UNITS = BigDecimal.ONE.subtract(MORNING_UNITS);

    /** Phân tách ca sáng / chiều theo giờ vào ca chiều (14:00). */
    public static final LocalTime AFTERNOON_BOUNDARY = LocalTime.of(14, 0);

    /** 15/4 – 15/10: mùa hè */
    public static boolean isSummer(LocalDate date) {
        int m = date.getMonthValue();
        int d = date.getDayOfMonth();
        if (m < 4 || m > 10) {
            return false;
        }
        if (m > 4 && m < 10) {
            return true;
        }
        if (m == 4) {
            return d >= 15;
        }
        return d < 16;
    }

    public double totalHours() {
        return morningHours + afternoonHours;
    }

    /** Ca thông tầm: làm liên tục từ giờ vào → giờ ra riêng, không trừ nghỉ trưa. */
    public double continuousHours() {
        LocalTime start = continuousStart != null ? continuousStart : morningStart;
        LocalTime end = continuousEnd != null ? continuousEnd : afternoonEnd;
        return Duration.between(start, end).toMinutes() / 60.0;
    }

    public LocalTime continuousDayStart() {
        return continuousStart != null ? continuousStart : morningStart;
    }

    public LocalTime continuousDayEnd() {
        return continuousEnd != null ? continuousEnd : afternoonEnd;
    }

    public Map<String, Object> toInfoMap() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("summer", summer);
        m.put("seasonLabel", summer ? "Mùa hè" : "Mùa đông");
        m.put("periodLabel", summer ? "15/4 – 15/10" : "16/10 – 14/4");
        m.put("morningStart", morningStart.toString());
        m.put("morningEnd", morningEnd.toString());
        m.put("afternoonStart", afternoonStart.toString());
        m.put("afternoonEnd", afternoonEnd.toString());
        m.put("continuousStart", continuousDayStart().toString());
        m.put("continuousEnd", continuousDayEnd().toString());
        m.put("morningHours", morningHours);
        m.put("afternoonHours", afternoonHours);
        m.put("continuousHours", continuousHours());
        m.put("totalHours", totalHours());
        m.put("morningUnits", morningUnits);
        m.put("afternoonUnits", afternoonUnits);
        m.put("morningUnitsLabel", formatUnitsLabel(morningUnits));
        m.put("afternoonUnitsLabel", formatUnitsLabel(afternoonUnits));
        return m;
    }

    /** Hiển thị thập phân 2 chữ số (0,67 / 0,33); tính toán vẫn dùng 2/3 và 1/3. */
    public static String formatUnitsLabel(BigDecimal units) {
        if (units == null) {
            return "0,00 công";
        }
        return units.setScale(2, RoundingMode.HALF_UP).toPlainString().replace('.', ',') + " công";
    }
}
