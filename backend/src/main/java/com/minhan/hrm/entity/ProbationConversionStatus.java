package com.minhan.hrm.entity;

public enum ProbationConversionStatus {
    /** Chờ HCNS duyệt */
    PENDING_HR,
    /** Chờ Giám đốc duyệt */
    PENDING_DIRECTOR,
    HR_REJECTED,
    DIRECTOR_REJECTED,
    /** Đã duyệt — chờ đến ngày lên chính thức */
    APPROVED,
    /** Đã chuyển trạng thái ACTIVE */
    APPLIED,
    CANCELLED
}
