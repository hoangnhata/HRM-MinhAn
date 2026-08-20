package com.minhan.hrm.service;

import com.minhan.hrm.entity.Employee;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa (toàn viện).
 * Dùng để phạm vi xem của HEAD_NURSING và chèn bước duyệt PENDING_NURSING_HEAD.
 */
public final class NursingBlockClassifier {

    public enum SubGroup {
        NURSE,
        TECHNICIAN,
        MIDWIFE,
        MEDICAL_SECRETARY,
        OTHER_NURSING
    }

    private static final Pattern MIDWIFE = Pattern.compile("ho\\s*sinh|midwife");
    private static final Pattern TECHNICIAN = Pattern.compile(
            "ky\\s*thuat\\s*vien|\\bktv\\b|technici");
    private static final Pattern MEDICAL_SECRETARY = Pattern.compile(
            "thu\\s*ky\\s*y\\s*khoa|thu\\s*ky\\s*ykhoa|medical\\s*secretar");
    private static final Pattern NURSE = Pattern.compile(
            "dieu\\s*duong|\\bdd\\b|y\\s*ta|\\bnurse\\b");
    /** Khối tổng: bất kỳ nhóm trên. */
    private static final Pattern BLOCK = Pattern.compile(
            "dieu\\s*duong|\\bdd\\b|ho\\s*sinh|ky\\s*thuat\\s*vien|\\bktv\\b|y\\s*ta|\\bnurse\\b"
                    + "|thu\\s*ky\\s*y\\s*khoa|thu\\s*ky\\s*ykhoa|medical\\s*secretar|midwife|technici");

    private NursingBlockClassifier() {}

    public static boolean matches(Employee employee) {
        if (employee == null) {
            return false;
        }
        String title = employee.getPosition() != null ? employee.getPosition().getTitle() : null;
        return matchesTitle(title);
    }

    public static boolean matchesTitle(String positionTitle) {
        String norm = normalize(positionTitle);
        return norm != null && !norm.isBlank() && BLOCK.matcher(norm).find();
    }

    public static SubGroup subGroup(Employee employee) {
        String title = employee != null && employee.getPosition() != null
                ? employee.getPosition().getTitle()
                : null;
        return subGroupOfTitle(title);
    }

    public static SubGroup subGroupOfTitle(String positionTitle) {
        String norm = normalize(positionTitle);
        if (norm == null || norm.isBlank()) {
            return SubGroup.OTHER_NURSING;
        }
        if (MEDICAL_SECRETARY.matcher(norm).find()) {
            return SubGroup.MEDICAL_SECRETARY;
        }
        if (MIDWIFE.matcher(norm).find()) {
            return SubGroup.MIDWIFE;
        }
        if (TECHNICIAN.matcher(norm).find()) {
            return SubGroup.TECHNICIAN;
        }
        if (NURSE.matcher(norm).find()) {
            return SubGroup.NURSE;
        }
        return SubGroup.OTHER_NURSING;
    }

    public static String subGroupLabel(SubGroup g) {
        return switch (g) {
            case NURSE -> "Điều dưỡng";
            case TECHNICIAN -> "KTV";
            case MIDWIFE -> "Hộ sinh";
            case MEDICAL_SECRETARY -> "Thư ký y khoa";
            case OTHER_NURSING -> "Khác (khối ĐD)";
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
