package com.minhan.hrm.entity;

public enum AttendanceRequestType {
    /** Giải trình đi muộn / về sớm (đã chấm công) */
    EXPLANATION,
    /** Đơn cập nhật công (quên chấm / thiếu ca) */
    UPDATE,
    /** Đơn nghỉ phép (khoảng ngày) */
    LEAVE,
    /** Đơn xin công tác (khoảng ngày + địa điểm) */
    BUSINESS_TRIP,
    /** Đơn điều động (trưởng phòng / điều dưỡng trưởng tạo cho nhân viên) */
    DEPLOYMENT
}
