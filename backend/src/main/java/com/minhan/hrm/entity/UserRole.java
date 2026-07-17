package com.minhan.hrm.entity;

public enum UserRole {
    ADMIN,
    EMPLOYEE,
    /** Phòng Hành chính — Nhân sự: tổng hợp xếp loại toàn viện */
    HR,
    /** Trưởng khoa / phòng: chấm kênh Trưởng khoa theo tháng */
    HEAD_DEPARTMENT,
    /** Điều dưỡng trưởng: chấm kênh ĐĐT theo tháng */
    HEAD_NURSING,
    /** Giám đốc — duyệt luân chuyển nhân viên */
    DIRECTOR,
}
