package com.minhan.hrm.util;

/**
 * Chuẩn hóa SĐT đăng nhập ERP/SSO (84xxxxxxxxx) và so khớp 9 số cuối.
 */
public final class PhoneLoginUtil {

    private PhoneLoginUtil() {}

    public static String toLoginPhone(String rawPhone) {
        if (rawPhone == null || rawPhone.isBlank()) {
            return null;
        }
        String digits = rawPhone.replaceAll("\\D", "");
        if (digits.isEmpty()) {
            return null;
        }
        if (digits.startsWith("0") && digits.length() >= 10) {
            return "84" + digits.substring(1);
        }
        if (digits.startsWith("84") && digits.length() >= 11) {
            return digits;
        }
        if (digits.length() < 9) {
            return null;
        }
        return digits;
    }

    public static String phoneLocal9(String loginPhone) {
        if (loginPhone == null || loginPhone.isBlank()) {
            return null;
        }
        String digits = loginPhone.replaceAll("\\D", "");
        if (digits.length() < 9) {
            return null;
        }
        return digits.substring(digits.length() - 9);
    }
}
