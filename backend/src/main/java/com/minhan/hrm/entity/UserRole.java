package com.minhan.hrm.entity;

import java.util.List;

public enum UserRole {
    ADMIN,
    EMPLOYEE,
    /** Phòng Hành chính — Nhân sự: tổng hợp xếp loại toàn viện */
    HR,
    /** HCNS 2: chuyên duyệt các đơn ở bước Hành chính — Nhân sự. */
    HR2,
    /** Lãnh đạo khoa/phòng; chức danh cụ thể được xác định từ hồ sơ nhân viên. */
    HEAD_DEPARTMENT,
    /**
     * Trưởng phòng HCNS — toàn bộ quyền trưởng khoa/phòng (theo khoa HCNS)
     * cộng chức năng duyệt HCNS 2 (toàn viện).
     */
    HEAD_HR,
    /**
     * Trưởng phòng Điều dưỡng — xem khối ĐD–KTV–HS–Thư ký y khoa (toàn viện);
     * duyệt bước trung gian đơn điều động / lên chính thức / trực chính của khối.
     */
    HEAD_NURSING,
    /** Giám đốc — duyệt luân chuyển nhân viên */
    DIRECTOR;

    public boolean isHeadDepartment() {
        return this == HEAD_DEPARTMENT || this == HEAD_HR;
    }

    public boolean isHr2() {
        return this == HR2 || this == HEAD_HR;
    }

    public static List<UserRole> headDepartmentRoles() {
        return List.of(HEAD_DEPARTMENT, HEAD_HR);
    }

    public static List<UserRole> hr2Roles() {
        return List.of(HR2, HEAD_HR);
    }
}
