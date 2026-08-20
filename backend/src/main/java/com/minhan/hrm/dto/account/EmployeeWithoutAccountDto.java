package com.minhan.hrm.dto.account;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class EmployeeWithoutAccountDto {
    Long employeeId;
    String employeeCode;
    String fullName;
    String phone;
    String attendanceCode;
    Long departmentId;
    String departmentName;
    String workUnitDetail;
    String positionTitle;
    String status;
    boolean missingPhone;
    boolean missingAttendanceCode;
}
