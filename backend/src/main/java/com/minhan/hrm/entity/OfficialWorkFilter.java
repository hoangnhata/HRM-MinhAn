package com.minhan.hrm.entity;

/**
 * Lọc nhân viên chính thức theo tình trạng làm việc (dựa trên cột tham gia BHXH).
 */
public enum OfficialWorkFilter {
    /** Không lọc thêm. */
    ALL,
    /** Đang làm việc — không ghi nhận nghỉ thai sản. */
    WORKING,
    /** Đang nghỉ thai sản. */
    MATERNITY_LEAVE
}
