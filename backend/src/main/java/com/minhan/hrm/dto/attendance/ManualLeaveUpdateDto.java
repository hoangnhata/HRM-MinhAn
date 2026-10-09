package com.minhan.hrm.dto.attendance;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

/** Admin sửa khoảng ngày / ghi chú của phép đã gắn (nhân viên giữ nguyên). */
@Data
public class ManualLeaveUpdateDto {
    @NotNull
    private LocalDate fromDate;
    @NotNull
    private LocalDate toDate;
    private String note;
    /** Đánh dấu LEAVE lên bảng công cho các ngày chưa có dữ liệu chấm công (mặc định true). */
    private Boolean applyAttendance = Boolean.TRUE;
}
