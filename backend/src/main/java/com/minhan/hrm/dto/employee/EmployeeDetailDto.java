package com.minhan.hrm.dto.employee;

import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.UserRole;
import lombok.Builder;
import lombok.Value;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@Value
@Builder(toBuilder = true)
public class EmployeeDetailDto {
    Long id;
    String employeeCode;
    Long userId;
    String username;
    String email;
    UserRole role;
    String fullName;
    String phone;
    String idCardNumber;
    LocalDate dateOfBirth;
    String address;
    String gender;
    Long departmentId;
    String departmentName;
    Long positionId;
    String positionTitle;
    LocalDate hireDate;
    EmployeeStatus status;
    /** FULL_TIME / PART_TIME */
    String employmentType;
    boolean continuousShift;
    /** true = được chọn mọi loại trực; false = chỉ trực kèm (TK). */
    boolean mainDutyAuthorized;
    SalaryInfoDto salary;
    List<ContractDto> contracts;
    /** Các trường bổ sung từ Excel TỔNG HỢP NHÂN LỰC BVMA (nếu có) */
    Map<String, Object> workforceProfile;
}
