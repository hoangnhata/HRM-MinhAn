package com.minhan.hrm.entity;

import java.util.EnumSet;
import java.util.Set;

/** Nhóm tab danh sách nhân viên trên UI. */
public enum EmployeeStatusGroup {
    /** Thử việc + thực tập. */
    TRIAL,
    /** Chính thức (+ nghỉ phép tạm). */
    OFFICIAL,
    /** Đã nghỉ việc. */
    TERMINATED;

    public Set<EmployeeStatus> statuses() {
        return switch (this) {
            case TRIAL -> EnumSet.of(EmployeeStatus.PROBATION, EmployeeStatus.INTERN);
            case OFFICIAL -> EnumSet.of(EmployeeStatus.ACTIVE, EmployeeStatus.ON_LEAVE);
            case TERMINATED -> EnumSet.of(EmployeeStatus.TERMINATED);
        };
    }
}
