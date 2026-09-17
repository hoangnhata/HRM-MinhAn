package com.minhan.hrm.entity;

public enum AttendanceRequestType {
    /** Giải trình đi muộn / về sớm (đã chấm công) */
    EXPLANATION,
    /** Đơn cập nhật công (quên chấm / thiếu ca) */
    UPDATE,
    /** Đơn nghỉ phép (khoảng ngày) — có tính công / trừ hạn mức phép năm */
    LEAVE,
    /** Đơn nghỉ không lương (khoảng ngày) — không tính công, không trừ hạn mức phép */
    UNPAID_LEAVE,
    /**
     * Đơn nghỉ chế độ (kết hôn / người thân mất, tối đa 3 ngày) — chính thức hưởng lương
     * cơ bản không trừ phép năm, thử việc nghỉ không lương.
     */
    PERSONAL_LEAVE,
    /** Đơn xin công tác (khoảng ngày + địa điểm) */
    BUSINESS_TRIP,
    /** Đơn điều động (trưởng phòng / điều dưỡng trưởng tạo cho nhân viên) */
    DEPLOYMENT
}
