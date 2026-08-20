package com.minhan.hrm.entity;

/** Loại khung ca trong danh mục xếp theo ngày. */
public enum ContinuousShiftKind {
    /** Ca thông tầm — vào đầu ngày / ra cuối ngày, không nghỉ trưa. */
    CONTINUOUS,
    /** Ca sáng–chiều — có nghỉ trưa; có thể đi sớm về sớm nhưng tổng ≥ 8 giờ. */
    SPLIT
}
