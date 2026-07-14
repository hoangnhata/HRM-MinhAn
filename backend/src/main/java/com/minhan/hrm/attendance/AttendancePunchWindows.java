package com.minhan.hrm.attendance;

/**
 * Khoảng thời gian (phút trước/sau mốc giờ ca) để lấy log chấm công.
 * Check-in: MIN trong cửa sổ · Check-out: MAX trong cửa sổ.
 */
public record AttendancePunchWindows(
        int morningInBeforeMin,
        int morningInAfterMin,
        int morningOutBeforeMin,
        int morningOutAfterMin,
        int afternoonInBeforeMin,
        int afternoonInAfterMin,
        int afternoonOutBeforeMin,
        int afternoonOutAfterMin) {

    public static AttendancePunchWindows defaults() {
        return new AttendancePunchWindows(60, 120, 60, 30, 90, 60, 60, 60);
    }
}
