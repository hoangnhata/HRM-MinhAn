package com.minhan.hrm.entity;

public enum NotificationCategory {
    SALARY_REVIEW,
    SALARY_ADJUSTMENT,
    INTERNAL,
    /** Thông báo toàn viện — bấm mở trang chủ tại mục thông báo */
    ANNOUNCEMENT,
    SYSTEM,
    /** Bảng lương đã chốt — nội dung nhạy cảm */
    PAYROLL,
    /** Bảng công / công kỳ — nội dung nhạy cảm */
    ATTENDANCE
}
