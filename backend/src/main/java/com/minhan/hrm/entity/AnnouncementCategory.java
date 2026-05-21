package com.minhan.hrm.entity;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum AnnouncementCategory {
    THONG_BAO_CHUNG("Thông báo chung"),
    DAO_TAO("Đào tạo"),
    LOP_HOC_PHAN("Lớp học phần"),
    CONG_TAC_SV("Công tác SV"),
    KHAO_THI_DBCL("Khảo thí & ĐBCL"),
    HOC_PHI_LE_PHI("Học phí, lệ phí"),
    QUY_CHE_QUY_DINH("Quy chế - Quy định"),
    KHOA("Khoa");

    private final String labelVi;

    public static boolean isValidName(String name) {
        if (name == null || name.isBlank()) {
            return false;
        }
        try {
            AnnouncementCategory.valueOf(name.trim());
            return true;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }
}
