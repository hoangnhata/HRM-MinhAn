package com.minhan.hrm.workforce;

import java.text.Normalizer;
import java.util.Locale;

public final class WorkforceInsurance {

    private WorkforceInsurance() {
    }

    public static boolean isMaternityLeave(String insuranceParticipation) {
        if (insuranceParticipation == null || insuranceParticipation.isBlank()) {
            return false;
        }
        String normalized = stripAccents(insuranceParticipation).toLowerCase(Locale.ROOT);
        return normalized.contains("thai san");
    }

    private static String stripAccents(String s) {
        return Normalizer.normalize(s, Normalizer.Form.NFD).replaceAll("\\p{M}+", "");
    }
}
