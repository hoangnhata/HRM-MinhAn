package com.minhan.hrm.attendance;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

public record LatePenaltySettings(List<LatePenaltyTier> tiers) {

    public record LatePenaltyTier(
            int sortOrder,
            int minMinutes,
            Integer maxMinutes,
            BigDecimal amount,
            boolean requiresDiscipline,
            String note) {

        String tierLabel() {
            if (requiresDiscipline) {
                if (maxMinutes == null) {
                    return ">" + (minMinutes - 1) + " phút/tháng — cần tự kiểm điểm";
                }
                return minMinutes + "–" + maxMinutes + " phút/tháng";
            }
            if (maxMinutes == null) {
                return "≥ " + minMinutes + " phút/tháng";
            }
            return minMinutes + "–" + maxMinutes + " phút/tháng";
        }
    }

    public static LatePenaltySettings defaults() {
        return new LatePenaltySettings(List.of(
                new LatePenaltyTier(1, 15, 30, new BigDecimal("40000"), false, null),
                new LatePenaltyTier(2, 31, 50, new BigDecimal("50000"), false, null),
                new LatePenaltyTier(3, 51, 60, new BigDecimal("100000"), false, null),
                new LatePenaltyTier(4, 61, 100, new BigDecimal("150000"), false, null),
                new LatePenaltyTier(5, 101, 200, new BigDecimal("200000"), false, null),
                new LatePenaltyTier(6, 201, null, BigDecimal.ZERO, true,
                        "Yêu cầu làm bản tự kiểm điểm và xem xét kỷ luật")));
    }

    public int exemptBelowMinutes() {
        return tiers.stream()
                .filter(t -> !t.requiresDiscipline())
                .map(LatePenaltyTier::minMinutes)
                .min(Integer::compareTo)
                .orElse(15);
    }

    public AttendancePenaltyCalculator.LatePenaltyResult latePenaltyForMonth(int totalLateMinutes) {
        if (totalLateMinutes < exemptBelowMinutes()) {
            return new AttendancePenaltyCalculator.LatePenaltyResult(BigDecimal.ZERO, null, false);
        }
        List<LatePenaltyTier> sorted = tiers.stream()
                .sorted(Comparator.comparingInt(LatePenaltyTier::sortOrder))
                .toList();
        for (LatePenaltyTier tier : sorted) {
            if (totalLateMinutes < tier.minMinutes()) {
                continue;
            }
            if (tier.maxMinutes() != null && totalLateMinutes > tier.maxMinutes()) {
                continue;
            }
            if (tier.requiresDiscipline()) {
                return new AttendancePenaltyCalculator.LatePenaltyResult(
                        BigDecimal.ZERO, tier.tierLabel(), true);
            }
            return new AttendancePenaltyCalculator.LatePenaltyResult(
                    tier.amount(), tier.tierLabel(), false);
        }
        LatePenaltyTier last = sorted.isEmpty() ? null : sorted.get(sorted.size() - 1);
        if (last != null && last.requiresDiscipline() && totalLateMinutes >= last.minMinutes()) {
            return new AttendancePenaltyCalculator.LatePenaltyResult(
                    BigDecimal.ZERO, last.tierLabel(), true);
        }
        return new AttendancePenaltyCalculator.LatePenaltyResult(BigDecimal.ZERO, null, false);
    }

    public List<Map<String, Object>> toDisplayTiers() {
        List<Map<String, Object>> out = new ArrayList<>();
        for (LatePenaltyTier t : tiers.stream().sorted(Comparator.comparingInt(LatePenaltyTier::sortOrder)).toList()) {
            if (t.requiresDiscipline()) {
                out.add(Map.of(
                        "sortOrder", t.sortOrder(),
                        "minMinutes", t.minMinutes(),
                        "maxMinutes", t.maxMinutes() != null ? t.maxMinutes() : "",
                        "amount", t.amount(),
                        "requiresDiscipline", true,
                        "note", t.note() != null ? t.note() : "",
                        "label", t.tierLabel()));
            } else {
                out.add(Map.of(
                        "sortOrder", t.sortOrder(),
                        "minMinutes", t.minMinutes(),
                        "maxMinutes", t.maxMinutes() != null ? t.maxMinutes() : "",
                        "amount", t.amount(),
                        "requiresDiscipline", false,
                        "label", t.tierLabel()));
            }
        }
        return out;
    }
}
