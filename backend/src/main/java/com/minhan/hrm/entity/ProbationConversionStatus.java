package com.minhan.hrm.entity;

public enum ProbationConversionStatus {
    /** Chờ Trưởng phòng Điều dưỡng (khối ĐD–KTV–HS–Thư ký) */
    PENDING_NURSING_HEAD,
    NURSING_HEAD_REJECTED,
    /** Chờ HCNS duyệt */
    PENDING_HR,
    /** Chờ Giám đốc duyệt (bác sĩ / điều dưỡng) */
    PENDING_DIRECTOR,
    HR_REJECTED,
    /** HCNS đề xuất gia hạn thử việc */
    HR_EXTEND_PROBATION,
    /** HCNS đề xuất ngừng hợp tác */
    HR_STOP_COOPERATION,
    DIRECTOR_REJECTED,
    /** Đã duyệt — chờ đến ngày lên chính thức */
    APPROVED,
    /** Đã chuyển trạng thái ACTIVE */
    APPLIED,
    CANCELLED
}
