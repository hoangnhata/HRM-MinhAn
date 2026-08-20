package com.minhan.hrm.entity;

public enum AttendanceRequestStatus {
    PENDING_HEAD,
    HEAD_REJECTED,
    /** Khối ĐD–KTV–HS–Thư ký: chờ Trưởng phòng Điều dưỡng */
    PENDING_NURSING_HEAD,
    NURSING_HEAD_REJECTED,
    PENDING_HR,
    HR_REJECTED,
    /** Cập nhật công / giải trình: chờ Giám đốc quyết định trừ tiền */
    PENDING_DIRECTOR,
    DIRECTOR_REJECTED,
    APPROVED,
    /** Đơn cập nhật công: duyệt không trừ tiền quên chấm; giải trình: miễn phạt muộn/sớm */
    APPROVED_NO_FINE,
    /** Người gửi thu hồi đơn trước khi hoàn tất duyệt */
    WITHDRAWN
}
