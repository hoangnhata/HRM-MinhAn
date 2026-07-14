package com.minhan.hrm.salary;

import java.util.Locale;

public final class SalaryQualifications {

    public static final String DAI_HOC = "Đại học";
    public static final String CAO_DANG = "Cao đẳng, trung cấp";
    public static final String LAO_DONG = "Lao động phổ thông";

    private SalaryQualifications() {
    }

    public static String fromTierGroup(int tierGroup) {
        return switch (tierGroup) {
            case 1 -> DAI_HOC;
            case 2 -> CAO_DANG;
            default -> LAO_DONG;
        };
    }

    public static int tierGroupFromQualification(String qualification) {
        String q = normalizeQualification(qualification);
        if (q.contains("dai hoc") || q.contains("đại học")) {
            return 1;
        }
        if (q.contains("cao dang") || q.contains("trung cap") || q.contains("cao đẳng")) {
            return 2;
        }
        return 3;
    }

    public static String normalizeQualification(String raw) {
        if (raw == null || raw.isBlank()) {
            return LAO_DONG;
        }
        String t = raw.trim();
        String lower = t.toLowerCase(Locale.ROOT);
        if (lower.contains("đại học") || lower.equals("dai hoc")) {
            return DAI_HOC;
        }
        if (lower.contains("cao đẳng") || lower.contains("trung cấp") || lower.contains("cao dang")) {
            return CAO_DANG;
        }
        if (lower.contains("lao động") || lower.contains("phổ thông")) {
            return LAO_DONG;
        }
        return t;
    }
}
