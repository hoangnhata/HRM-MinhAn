package com.minhan.hrm.entity;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum DutyShiftType {
    TRUC_TOI_CHINH("tructoichinh", "Trực chính"),
    TC1("TC1", "Trực cọc 1 cấp cứu"),
    TCC("TCC", "Trực đa khoa / cấp cứu / cọc 1 nội nhi"),
    TK("TK", "Trực kèm");

    private final String code;
    private final String label;

    public static DutyShiftType fromCode(String code) {
        if (code == null || code.isBlank()) {
            throw new IllegalArgumentException("Loại ca trực không hợp lệ");
        }
        for (DutyShiftType t : values()) {
            if (t.code.equalsIgnoreCase(code.trim())) {
                return t;
            }
        }
        throw new IllegalArgumentException("Loại ca trực không hợp lệ: " + code);
    }
}
