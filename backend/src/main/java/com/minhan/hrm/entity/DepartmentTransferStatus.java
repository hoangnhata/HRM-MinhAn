package com.minhan.hrm.entity;

public enum DepartmentTransferStatus {
    /** Chờ giám đốc duyệt */
    PENDING_DIRECTOR,
    REJECTED,
    /** Đã duyệt — chờ đến ngày hiệu lực (hoặc đã áp dụng ngay nếu ngày ≤ hôm nay) */
    APPROVED,
    /** Đã chuyển phòng ban trong hệ thống */
    APPLIED,
    CANCELLED
}
