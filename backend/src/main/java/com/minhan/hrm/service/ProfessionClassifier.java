package com.minhan.hrm.service;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Phân loại đối tượng nghề nghiệp theo chức danh (toàn viện)
 * cho báo cáo trình độ chuyên môn.
 */
public final class ProfessionClassifier {

    public enum Profession {
        DOCTOR,
        NURSE,
        MIDWIFE,
        TECHNICIAN,
        ASSISTANT_PHYSICIAN,
        PHARMACIST,
        OTHER
    }

    private static final Pattern MIDWIFE = Pattern.compile("ho\\s*sinh|midwife");
    private static final Pattern TECHNICIAN = Pattern.compile(
            "ky\\s*thuat\\s*vien|\\bktv\\b|technici");
    private static final Pattern NURSE = Pattern.compile(
            "dieu\\s*duong|\\bdd\\b|y\\s*ta|\\bnurse\\b");
    /** Y sĩ / Y sỹ — trước bác sĩ để tránh nhầm. */
    private static final Pattern ASSISTANT_PHYSICIAN = Pattern.compile(
            "\\by\\s*s[iy]\\b|assistant\\s*physician|physician\\s*assistant");
    private static final Pattern DOCTOR = Pattern.compile(
            "bac\\s*si|\\bdoctor\\b|physician");
    private static final Pattern PHARMACIST = Pattern.compile(
            "duoc\\s*si|\\bduocsy\\b|pharmacist");

    private ProfessionClassifier() {}

    public static Profession classify(String positionTitle) {
        String norm = normalize(positionTitle);
        if (norm == null || norm.isBlank()) {
            return Profession.OTHER;
        }
        // Thứ tự ưu tiên: HS → KTV → ĐD → Y sĩ → Bác sĩ → Dược sĩ
        if (MIDWIFE.matcher(norm).find()) {
            return Profession.MIDWIFE;
        }
        if (TECHNICIAN.matcher(norm).find()) {
            return Profession.TECHNICIAN;
        }
        if (NURSE.matcher(norm).find()) {
            return Profession.NURSE;
        }
        if (ASSISTANT_PHYSICIAN.matcher(norm).find()) {
            return Profession.ASSISTANT_PHYSICIAN;
        }
        if (DOCTOR.matcher(norm).find()) {
            return Profession.DOCTOR;
        }
        if (PHARMACIST.matcher(norm).find()) {
            return Profession.PHARMACIST;
        }
        return Profession.OTHER;
    }

    public static boolean isTargetProfession(Profession p) {
        return p != null && p != Profession.OTHER;
    }

    public static String label(Profession p) {
        return switch (p) {
            case DOCTOR -> "Bác sĩ";
            case NURSE -> "Điều dưỡng";
            case MIDWIFE -> "Hộ sinh";
            case TECHNICIAN -> "Kỹ thuật viên";
            case ASSISTANT_PHYSICIAN -> "Y sĩ";
            case PHARMACIST -> "Dược sĩ";
            case OTHER -> "Khác";
        };
    }

    public static int sortOrder(Profession p) {
        return switch (p) {
            case DOCTOR -> 1;
            case NURSE -> 2;
            case MIDWIFE -> 3;
            case TECHNICIAN -> 4;
            case ASSISTANT_PHYSICIAN -> 5;
            case PHARMACIST -> 6;
            case OTHER -> 99;
        };
    }

    public static String normalize(String raw) {
        if (raw == null) {
            return null;
        }
        String n = Normalizer.normalize(raw, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.ROOT)
                .replace('đ', 'd');
        return n.replaceAll("\\s+", " ").trim();
    }
}
