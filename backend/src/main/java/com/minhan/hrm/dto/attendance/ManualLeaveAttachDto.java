package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

/** Admin gắn phép đã nghỉ ngoài hệ thống cho 1 nhân viên. */
@Data
public class ManualLeaveAttachDto {
    @NotNull
    private Long employeeId;
    @NotNull
    private LocalDate fromDate;
    @NotNull
    private LocalDate toDate;
    private String note;
    /** Đánh dấu LEAVE lên bảng công cho các ngày chưa có dữ liệu chấm công (mặc định true). */
    private Boolean applyAttendance = Boolean.TRUE;
}
