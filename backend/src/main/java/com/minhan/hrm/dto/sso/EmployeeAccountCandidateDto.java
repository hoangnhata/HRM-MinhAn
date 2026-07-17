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
    private Integer roleId;
    private Integer roleIdTs;
}
