package com.minhan.hrm.entity;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum DutyRoleTier {
    BS_NSN_XQ_SA("BS NSN XQ SA", "Bác sĩ NSN XQ SA"),
    NV_TAI_KHOA("NV_TAI_KHOA", "Nhân viên tại khoa"),
    THU_NGAN_DUOC("THU_NGAN_DUOC", "Thu ngân dược"),
    BS("BS", "Bác sĩ"),
    DIEU_DUONG("DIEU_DUONG", "Điều dưỡng"),
    BS_DA_KHOA("BS_DA_KHOA", "Bác sĩ trực đa khoa"),
    DD_CAP_CUU("DD_CAP_CUU", "Điều dưỡng trực cấp cứu"),
    COC1_NOI_NHI("COC1_NOI_NHI", "Cọc 1 nội nhi");

    private final String code;
    private final String label;

    public static DutyRoleTier fromCode(String code) {
        if (code == null || code.isBlank()) {
            throw new IllegalArgumentException("Vị trí trực không hợp lệ");
        }
        for (DutyRoleTier t : values()) {
            if (t.code.equalsIgnoreCase(code.trim())) {
                return t;
            }
        }
        throw new IllegalArgumentException("Vị trí trực không hợp lệ: " + code);
    }
}
