package com.minhan.hrm.entity;

public enum AttendanceRequestStatus {
    PENDING_HEAD,
    HEAD_REJECTED,
    PENDING_HR,
    HR_REJECTED,
    APPROVED,
    /** Đơn cập nhật công: HR duyệt không trừ tiền quên chấm */
    APPROVED_NO_FINE,
    /** Người gửi thu hồi đơn trước khi hoàn tất duyệt */
    WITHDRAWN
}
