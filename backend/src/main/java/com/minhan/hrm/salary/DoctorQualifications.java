package com.minhan.hrm.salary;

import java.util.Locale;

/** Chuẩn hoá mã trình độ bác sỹ theo sheet «tbl» / «bằng cấp» Excel BVMA. */
public final class DoctorQualifications {

    private DoctorQualifications() {
    }

    /**
     * Chuẩn hoá mã: ĐK, ĐKCT, CCHN, CCHNCT, CK1, CK2, NOI_TRU.
     */
    public static String normalize(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String t = raw.trim();
        // Bỏ hậu tố khoảng năm gắn liền mã: CCHN0-2, CK10-2, NỘI TRÚ0-2…
        t = t.replaceAll("(?i)(thử\\s*việc|thu\\s*viec).*$", "")
                .replaceAll("\\d.*$", "")
                .trim();
        if (t.isEmpty()) {
            t = raw.trim();
        }
        String u = stripAccents(t).toUpperCase(Locale.ROOT).replaceAll("[\\s_-]+", "");
        if (u.equals("DKCT") || u.equals("DKC")) {
            return "DKCT";
        }
        if (u.equals("DK") || u.equals("BSCHUACOCCCN") || u.equals("BSCHUACCHN")) {
            return "DK";
        }
        if (u.equals("CCHNCT") || u.equals("CCHNCTH") || u.contains("CCHNCT")) {
            return "CCHNCT";
        }
        if (u.equals("CCHN") || u.contains("CCHN")) {
            return "CCHN";
        }
        if (u.equals("CK2") || u.equals("CKII")) {
            return "CK2";
        }
        if (u.equals("CK1") || u.equals("CKI") || u.equals("CK")) {
            // «CK10-2» sau khi cắt số → «CK» — mặc định CK1 theo thang BVMA
            return "CK1";
        }
        if (u.contains("NOITRU") || u.contains("NOI_TRU") || u.equals("NT")) {
            return "NOI_TRU";
        }
        // Giữ mã đã viết hoa nếu không nhận diện
        String keep = t.toUpperCase(Locale.ROOT).replace('Đ', 'D');
        if (keep.contains("NỘI") || keep.contains("NOI")) {
            return "NOI_TRU";
        }
        return keep.replaceAll("\\s+", "_");
    }

    public static String displayName(String code) {
        if (code == null) {
            return "";
        }
        return switch (normalize(code)) {
            case "DK" -> "Bác sỹ chưa có CCHN";
            case "DKCT" -> "Bác sỹ chưa có CCHN (ĐKCT)";
            case "CCHN" -> "Bác sỹ có CCHN";
            case "CCHNCT" -> "Bác sỹ có CCHN (có thời hạn)";
            case "CK1" -> "CK1";
            case "CK2" -> "CK2";
            case "NOI_TRU" -> "Nội trú";
            default -> code;
        };
    }

    private static String stripAccents(String s) {
        String n = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD);
        return n.replaceAll("\\p{M}+", "").replace('đ', 'd').replace('Đ', 'D');
    }
}
