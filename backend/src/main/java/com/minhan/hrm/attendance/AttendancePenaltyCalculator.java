package com.minhan.hrm.attendance;

import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.AttendanceShiftScope;
import com.minhan.hrm.entity.AttendanceUpdateKind;
import com.minhan.hrm.entity.AttendanceWorkRequest;

import java.math.BigDecimal;
import java.time.LocalTime;
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
     * Ca thông tầm chỉ có 2 mốc (vào đầu ngày / ra cuối ngày).
     */
    public static int forgotFineUnitsForUpdate(AttendanceUpdateKind kind, AttendanceRecord rec) {
        return forgotFineUnitsForUpdate(kind, rec, false);
    }

    public static int forgotFineUnitsForUpdate(
            AttendanceUpdateKind kind, AttendanceRecord rec, boolean continuousShift) {
        if (continuousShift) {
            if (rec == null) {
                return 2;
            }
            LocalTime dayIn = rec.getMorningCheckIn() != null ? rec.getMorningCheckIn() : rec.getCheckIn();
            LocalTime dayOut = rec.getAfternoonCheckOut() != null ? rec.getAfternoonCheckOut() : rec.getCheckOut();
            // Cột ca trống nhưng còn log máy → vẫn tính đã có giờ vào (tránh trừ 2 khi chỉ quên ra)
            if (dayIn == null || dayOut == null) {
                List<LocalTime> punches = parsePunchTimes(rec.getPunchTimesJson());
                if (dayIn == null && !punches.isEmpty()) {
                    dayIn = punches.get(0);
                }
                if (dayOut == null && punches.size() >= 2) {
                    LocalTime last = punches.get(punches.size() - 1);
                    // Chỉ coi là giờ ra khi cách giờ vào ≥ 4 giờ (tránh 6h07+6h14 thành đủ 2 mốc)
                    if (dayIn != null && java.time.Duration.between(dayIn, last).toMinutes() >= 4 * 60) {
                        dayOut = last;
                    }
                }
            }
            return missingPunchCount(dayIn, dayOut);
        }
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

    private static List<LocalTime> parsePunchTimes(String json) {
        if (json == null || json.isBlank() || "[]".equals(json.trim())) {
            return List.of();
        }
        try {
            String body = json.trim();
            if (body.startsWith("[")) {
                body = body.substring(1);
            }
            if (body.endsWith("]")) {
                body = body.substring(0, body.length() - 1);
            }
            if (body.isBlank()) {
                return List.of();
            }
            List<LocalTime> out = new java.util.ArrayList<>();
            for (String part : body.split(",")) {
                String t = part.trim().replace("\"", "");
                if (t.isEmpty()) {
                    continue;
                }
                if (t.length() >= 8) {
                    t = t.substring(0, 8);
                }
                out.add(LocalTime.parse(t.length() == 5 ? t + ":00" : t));
            }
            out.sort(LocalTime::compareTo);
            return out;
        } catch (Exception e) {
            return List.of();
        }
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
        return forgotFineUnitsForWorkRequest(req, false);
    }

    public static int forgotFineUnitsForWorkRequest(AttendanceWorkRequest req, boolean continuousOrTwoPunch) {
        if (req.getForgotFineUnits() != null && req.getForgotFineUnits() > 0) {
            int stored = req.getForgotFineUnits();
            return continuousOrTwoPunch ? Math.min(stored, 2) : stored;
        }
        if (continuousOrTwoPunch) {
            return 2;
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
