package com.minhan.hrm.service;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Chuẩn hoá chuỗi «Trình độ / bằng cấp» (free-text) thành nhóm trình độ
 * để tổng hợp báo cáo.
 */
public final class DegreeLevelNormalizer {

    public enum Level {
        TIEN_SI,
        THAC_SI,
        CK2,
        CK1,
        DAI_HOC,
        CAO_DANG,
        TRUNG_CAP,
        SO_CAP,
        OTHER,
        MISSING
    }

    private static final Pattern TIEN_SI = Pattern.compile(
            "tien\\s*si|\\bts\\b|\\bphd\\b|doctor\\s*of\\s*philosophy");
    private static final Pattern THAC_SI = Pattern.compile(
            "thac\\s*si|\\bths\\b|\\bmaster\\b|\\bmsc\\b");
    private static final Pattern CK2 = Pattern.compile(
            "chuyen\\s*khoa\\s*(ii|2|hai)|\\bck\\s*(ii|2)\\b|\\bbsck\\s*(ii|2)\\b|\\bckii\\b");
    private static final Pattern CK1 = Pattern.compile(
            "chuyen\\s*khoa\\s*(i|1|mot)|\\bck\\s*(i|1)\\b|\\bbsck\\s*(i|1)\\b|\\bcki\\b|noi\\s*tru");
    private static final Pattern DAI_HOC = Pattern.compile(
            "dai\\s*hoc|\\bdh\\b|cu\\s*nhan|\\bbachelor\\b|\\bbsc\\b|\\bbs\\b");
    private static final Pattern CAO_DANG = Pattern.compile(
            "cao\\s*dang|\\bcd\\b|\\bcao\\s*dang\\b");
    private static final Pattern TRUNG_CAP = Pattern.compile(
            "trung\\s*cap|\\btc\\b");
    private static final Pattern SO_CAP = Pattern.compile(
            "so\\s*cap|chung\\s*chi|certificate|cnkt|nghe");

    private DegreeLevelNormalizer() {}

    public static Level normalize(String rawDegree) {
        if (rawDegree == null || rawDegree.isBlank()) {
            return Level.MISSING;
        }
        String norm = fold(rawDegree);
        if (norm.isBlank()) {
            return Level.MISSING;
        }
        // Ưu tiên trình độ cao → thấp
        if (TIEN_SI.matcher(norm).find()) {
            return Level.TIEN_SI;
        }
        if (THAC_SI.matcher(norm).find()) {
            return Level.THAC_SI;
        }
        if (CK2.matcher(norm).find()) {
            return Level.CK2;
        }
        if (CK1.matcher(norm).find()) {
            return Level.CK1;
        }
        if (DAI_HOC.matcher(norm).find()) {
            return Level.DAI_HOC;
        }
        if (CAO_DANG.matcher(norm).find()) {
            return Level.CAO_DANG;
        }
        if (TRUNG_CAP.matcher(norm).find()) {
            return Level.TRUNG_CAP;
        }
        if (SO_CAP.matcher(norm).find()) {
            return Level.SO_CAP;
        }
        return Level.OTHER;
    }

    public static String label(Level level) {
        return switch (level) {
            case TIEN_SI -> "Tiến sĩ";
            case THAC_SI -> "Thạc sĩ";
            case CK2 -> "Chuyên khoa II";
            case CK1 -> "Chuyên khoa I";
            case DAI_HOC -> "Đại học";
            case CAO_DANG -> "Cao đẳng";
            case TRUNG_CAP -> "Trung cấp";
            case SO_CAP -> "Sơ cấp / chứng chỉ";
            case OTHER -> "Khác / chưa chuẩn hoá";
            case MISSING -> "Chưa cập nhật";
        };
    }

    public static int sortOrder(Level level) {
        return switch (level) {
            case TIEN_SI -> 1;
            case THAC_SI -> 2;
            case CK2 -> 3;
            case CK1 -> 4;
            case DAI_HOC -> 5;
            case CAO_DANG -> 6;
            case TRUNG_CAP -> 7;
            case SO_CAP -> 8;
            case OTHER -> 9;
            case MISSING -> 10;
        };
    }

    private static String fold(String raw) {
        String n = Normalizer.normalize(raw, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.ROOT)
                .replace('đ', 'd');
        return n.replaceAll("\\s+", " ").trim();
    }
}
