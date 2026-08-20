package com.minhan.hrm.dto.account;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class AccountMeResponse {
    Long userId;
    String username;
    String email;
    /** Vai trò HRM (SSO UserAppRoles) — không lấy từ ERP roles. */
    String role;
    String fullName;
    Long employeeId;
    boolean enabled;
    boolean directorApprovalEnabled;
    /** true = được xem menu/API báo cáo nhân lực (cấp bởi Admin). */
    boolean reportViewEnabled;
    /** true = trưởng khoa chỉ quản lý bộ phận (workUnitDetail) của mình. */
    boolean workUnitScoped;
    boolean mustChangePassword;
    String createdAt;
    String phone;
    String address;
    String departmentName;
    Long departmentId;
    String positionTitle;
    /** Bộ phận (workUnitDetail) — khác Phòng ban */
    String workUnitDetail;
    /** true khi đã liên kết token ERP và lấy được hồ sơ từ ERP */
    boolean erpLinked;
    /** Ngày sinh (yyyy-MM-dd) từ ERP */
    String dateOfBirth;
    String userAvatar;
    Integer userEnrollNumber;
    /** Mã nhân viên HRM — thường là số CCCD/CMND. */
    String employeeCode;
    /** Đã có chữ ký số (ảnh) gắn tài khoản */
    boolean hasSignature;
    /** Đã có ảnh đại diện local (ưu tiên hơn ERP) */
    boolean hasAvatar;
    /** true nếu user được xem bảng lương (NV thử việc cần có ngày vào làm chính thức). */
    boolean canViewSalary;
    /** Trạng thái HRM của nhân viên liên kết (ACTIVE, PROBATION, …). */
    String employeeStatus;
    /** URL lấy ảnh chữ ký (khi hasSignature) */
    String signatureUrl;
}
