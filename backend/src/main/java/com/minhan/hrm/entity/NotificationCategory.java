package com.minhan.hrm.entity;

public enum NotificationCategory {
    SALARY_REVIEW,
    SALARY_ADJUSTMENT,
    INTERNAL,
    /** Legacy category — announcement board removed; actionPath resolves to home */
    ANNOUNCEMENT,
    SYSTEM,
    /** Bảng lương đã chốt — nội dung nhạy cảm */
    PAYROLL,
    /** Bảng công / công kỳ — nội dung nhạy cảm */
    ATTENDANCE,
    /** Luân chuyển phòng ban — chờ / kết quả duyệt Giám đốc */
    DEPARTMENT_TRANSFER,
    /** Chuyển thử việc / thực tập lên chính thức */
    PROBATION_CONVERSION,
    /** Đề xuất chế độ nuôi con nhỏ — chờ HCNS duyệt */
    YOUNG_CHILD,
    /** Phiếu đề xuất cử CBNV đào tạo / bồi dưỡng */
    TRAINING_PROPOSAL,
    /** Phiếu đề xuất cử CBNV tham gia hội thảo */
    SEMINAR_PROPOSAL,
    /** Đơn đề nghị chuyển từ trực kèm lên trực chính */
    MAIN_DUTY_AUTHORIZATION,
    /** Đề xuất chỉnh cấu hình ca sáng/chiều — chờ HCNS duyệt */
    SHIFT_CONFIG_CHANGE,
    /** Đánh giá NV khối ĐD — chờ HCNS / Giám đốc duyệt */
    NURSING_EVALUATION
}
