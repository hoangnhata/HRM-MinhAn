package com.minhan.hrm.dto.employee;

import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.UserRole;
import lombok.Builder;
import lombok.Value;

import java.time.LocalDate;

@Value
@Builder
public class EmployeeSummaryDto {
    Long id;
    String employeeCode;
    Long userId;
    String username;
    String fullName;
    String departmentName;
    /** Bộ phận / đơn vị chi tiết (từ hồ sơ nhân lực). */
    String workUnitDetail;
    String positionTitle;
    UserRole role;
    EmployeeStatus status;
    /** FULL_TIME / PART_TIME */
    String employmentType;
    LocalDate hireDate;
    /** Ngày bắt đầu thử việc / thực tập (nếu có). */
    LocalDate probationStartDate;
    /** Số tháng đã thử việc (tính đến hôm nay). */
    Integer probationMonths;
    /** Quá 3 tháng thử việc — cần chuyển chính thức hoặc gia hạn. */
    Boolean probationOverdue;
    /** Giá trị cột tham gia BHXH từ hồ sơ nhân lực. */
    String insuranceParticipation;
    /** Đang nghỉ thai sản (theo cột tham gia BHXH). */
    Boolean maternityLeave;
    /** Đang đi đào tạo / bồi dưỡng. */
    Boolean onTraining;
    /** Đã được duyệt đơn trực chính. */
    Boolean mainDutyAuthorized;
}
