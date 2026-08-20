package com.minhan.hrm.dto.sso;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** Nhân viên HRM chưa có tài khoản đăng nhập trên sso_db (ứng viên để cấp tài khoản mới). */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmployeeAccountCandidateDto {
    /** UserEnrollNumber — chính là mã chấm công, dùng làm path param khi cấp tài khoản. */
    private Long id;
    private String name;
    private String dept;
    private String phone;
    private String cccd;
    /** true nếu chưa có SĐT hợp lệ — cần cập nhật SĐT trên HRM trước khi cấp TK */
    private Boolean missingPhone;
    private String employeeStatus;
    /** Id bản ghi employees (khác UserEnrollNumber khi NV thử việc). */
    private Long hrmEmployeeId;
    /** Mã nhân viên HRM (vd TV-15071990). */
    private String employeeCode;
    /** Mã chấm công hiện có trên HRM (nếu có). */
    private String attendanceCode;
    /** true nếu chưa có mã chấm công — cần nhập khi cấp TK */
    private Boolean missingAttendanceCode;
    /** FULL_TIME (TTG) / PART_TIME (BTG). */
    private String employmentType;
    /** RoleId đề xuất trên sso_db (mặc định 3 = nhân viên thường). */
    private Integer roleId;
    /** RoleIdTs đề xuất (mặc định 3). */
    private Integer roleIdTs;
}
