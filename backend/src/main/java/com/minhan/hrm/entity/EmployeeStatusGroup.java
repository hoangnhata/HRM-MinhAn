package com.minhan.hrm.entity;

import java.util.EnumSet;
import java.util.Set;

/** Nhóm tab danh sách nhân viên trên UI. */
public enum EmployeeStatusGroup {
    /** Đang làm (chính thức + thử việc + thực tập) — dùng chọn NV công/lương. */
    WORKING,
    /** Thử việc + thực tập. */
    TRIAL,
    /** Chính thức (+ nghỉ phép tạm). */
    OFFICIAL,
    /** Đã nghỉ việc. */
    TERMINATED;

    public Set<EmployeeStatus> statuses() {
        return switch (this) {
            case WORKING -> EnumSet.of(
                    EmployeeStatus.ACTIVE, EmployeeStatus.PROBATION, EmployeeStatus.INTERN);
            case TRIAL -> EnumSet.of(EmployeeStatus.PROBATION, EmployeeStatus.INTERN);
            case OFFICIAL -> EnumSet.of(EmployeeStatus.ACTIVE, EmployeeStatus.ON_LEAVE);
            case TERMINATED -> EnumSet.of(EmployeeStatus.TERMINATED);
        };
    }
}
