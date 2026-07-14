package com.minhan.hrm.attendance;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public record ForgotPenaltySettings(
        BigDecimal tier1Amount,
        int tier2Min,
        int tier2Max,
        BigDecimal tier2Amount,
        BigDecimal tier3Amount) {

    public static ForgotPenaltySettings defaults() {
        return new ForgotPenaltySettings(
                new BigDecimal("10000"),
                2,
                4,
                new BigDecimal("50000"),
                new BigDecimal("100000"));
    }

    /**
     * Mức phạt / lần theo <strong>tổng</strong> số lần quên trong tháng:
     * 1 lần → 10k; 2–4 lần → 50k/lần; từ 5 lần → 100k/lần.
     */
    public BigDecimal rateForMonthlyCount(int finedOccurrenceCount) {
        if (finedOccurrenceCount <= 1) {
            return tier1Amount;
        }
        if (finedOccurrenceCount <= tier2Max) {
            return tier2Amount;
        }
        return tier3Amount;
    }

    /** @deprecated dùng {@link #rateForMonthlyCount(int)} — giữ cho tương thích API cũ */
    public BigDecimal amountForOccurrence(int occurrenceIndexInMonth) {
        return rateForMonthlyCount(occurrenceIndexInMonth);
    }

    public BigDecimal totalForgotPenalty(int finedOccurrenceCount) {
        if (finedOccurrenceCount <= 0) {
            return BigDecimal.ZERO;
        }
        return rateForMonthlyCount(finedOccurrenceCount)
                .multiply(BigDecimal.valueOf(finedOccurrenceCount));
    }

    public List<Map<String, Object>> toDisplayTiers() {
        return List.of(
                Map.of("occurrences", "1", "amountPerTime", tier1Amount),
                Map.of("occurrences", tier2Min + "-" + tier2Max, "amountPerTime", tier2Amount),
                Map.of("occurrences", ">" + tier2Max, "amountPerTime", tier3Amount),
                Map.of("note", "Áp dụng theo tổng lần quên trong tháng: 1 lần = 10k; 2–4 lần = 50k × số lần; ≥5 lần = 100k × số lần"));
    }
}
