package com.minhan.hrm.attendance;

import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.AttendanceShiftScope;
import com.minhan.hrm.entity.AttendanceUpdateKind;
import com.minhan.hrm.entity.AttendanceWorkRequest;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public final class AttendancePenaltyCalculator {

    private AttendancePenaltyCalculator() {
    }

    /** Phạt đi muộn / về sớm theo tổng phút trong tháng (một mức cho cả tháng). */
    public static LatePenaltyResult latePenaltyForMonth(int totalLateMinutes) {
        return LatePenaltySettings.defaults().latePenaltyForMonth(totalLateMinutes);
    }

    public static LatePenaltyResult latePenaltyForMonth(int totalLateMinutes, LatePenaltySettings settings) {
        return settings.latePenaltyForMonth(totalLateMinutes);
    }

    /**
     * Phạt quên chấm công theo số lần quên thực tế khi nộp đơn:
     * thiếu 1 mốc (vào hoặc ra) = 1 lần; thiếu cả ca = 2 lần;
     * cả ngày = số mốc còn thiếu trên cả 2 ca (tối đa 4; đã có một phần chấm thì không hardcode 4).
     */
    public static int forgotFineUnitsForUpdate(AttendanceUpdateKind kind, AttendanceRecord rec) {
        if (kind == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT) {
            if (rec == null) {
                return 4;
            }
            int missing = countAbsentPunches(rec.getMorningCheckIn(), rec.getMorningCheckOut())
                    + countAbsentPunches(rec.getAfternoonCheckIn(), rec.getAfternoonCheckOut());
            return missing > 0 ? missing : 4;
        }
        if (kind == AttendanceUpdateKind.MORNING_SUPPLEMENT) {
            return missingPunchCount(
                    rec != null ? rec.getMorningCheckIn() : null,
                    rec != null ? rec.getMorningCheckOut() : null);
        }
        if (kind == AttendanceUpdateKind.AFTERNOON_SUPPLEMENT) {
            return missingPunchCount(
                    rec != null ? rec.getAfternoonCheckIn() : null,
                    rec != null ? rec.getAfternoonCheckOut() : null);
        }
        return 2;
    }

    /** Số mốc chưa có (0–2); không ép về 2 khi ca đã đủ. */
    private static int countAbsentPunches(java.time.LocalTime in, java.time.LocalTime out) {
        int missing = 0;
        if (in == null) {
            missing++;
        }
        if (out == null) {
            missing++;
        }
        return missing;
    }

    private static int missingPunchCount(java.time.LocalTime in, java.time.LocalTime out) {
        int missing = countAbsentPunches(in, out);
        if (missing == 0) {
            return 2;
        }
        return missing;
    }

    public static int forgotFineUnitsForShiftScope(AttendanceShiftScope scope) {
        if (scope == AttendanceShiftScope.FULL_DAY) {
            return 4;
        }
        return 2;
    }

    /** Ưu tiên số lần quên đã lưu khi nộp đơn; fallback cho đơn cũ. */
    public static int forgotFineUnitsForWorkRequest(AttendanceWorkRequest req) {
        if (req.getForgotFineUnits() != null && req.getForgotFineUnits() > 0) {
            return req.getForgotFineUnits();
        }
        if (req.getUpdateKind() != null) {
            return switch (req.getUpdateKind()) {
                case FULL_DAY_SUPPLEMENT -> 4;
                case MORNING_SUPPLEMENT, AFTERNOON_SUPPLEMENT -> 2;
            };
        }
        return forgotFineUnitsForShiftScope(req.getShiftScope());
    }

    public static int forgotFineUnitsForUpdateKind(AttendanceUpdateKind kind) {
        if (kind == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT) {
            return 4;
        }
        return 2;
    }

    public static BigDecimal forgotPenaltyForOccurrence(int occurrenceIndexInMonth) {
        return ForgotPenaltySettings.defaults().amountForOccurrence(occurrenceIndexInMonth);
    }

    public static BigDecimal totalForgotPenalty(int finedOccurrenceCount) {
        return ForgotPenaltySettings.defaults().totalForgotPenalty(finedOccurrenceCount);
    }

    public static BigDecimal totalForgotPenalty(int finedOccurrenceCount, ForgotPenaltySettings settings) {
        return settings.totalForgotPenalty(finedOccurrenceCount);
    }

    public record LatePenaltyResult(BigDecimal amount, String tierLabel, boolean requiresDiscipline) {
    }

    public static List<Map<String, Object>> latePenaltyTiers() {
        return LatePenaltySettings.defaults().toDisplayTiers();
    }

    public static List<Map<String, Object>> latePenaltyTiers(LatePenaltySettings settings) {
        return settings.toDisplayTiers();
    }

    public static List<Map<String, Object>> forgotPenaltyTiers() {
        return ForgotPenaltySettings.defaults().toDisplayTiers();
    }
}
