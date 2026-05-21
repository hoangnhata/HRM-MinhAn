package com.minhan.hrm.entity;

public enum UserRole {
    ADMIN,
    EMPLOYEE,
    /** Phòng Hành chính — Nhân sự: tổng hợp xếp loại toàn viện */
    HR,
    /** Trưởng khoa / phòng: chấm kênh Trưởng khoa theo tháng */
    HEAD_DEPARTMENT,
    /** Điều dưỡng trưởng: chấm kênh ĐDT theo tháng */
    HEAD_NURSING,
}
