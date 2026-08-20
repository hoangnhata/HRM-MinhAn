package com.minhan.hrm.dto.employee;

import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmploymentType;
import com.minhan.hrm.entity.UserRole;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class EmployeeCreateRequest {

    @NotNull
    private UserRole role;

    /** Tuỳ chọn — trống thì tự sinh từ SĐT (@minhan.local). */
    private String email;

    /** Bắt buộc với EMPLOYEE — dùng làm username đăng nhập. */
    private String phone;

    /** Chỉ dùng khi tạo tài khoản quản lý (HR / trưởng khoa / ĐD trưởng). */
    private String username;
    private String password;

    @NotBlank
    private String fullName;

    /** Tuỳ chọn — bổ sung sau; trống thì mã NV tạm theo SĐT. */
    private String idCardNumber;
    private LocalDate dateOfBirth;
    private String address;
    private String gender;

    @NotNull
    private Long departmentId;

    /** Tuỳ chọn — trống thì gán chức vụ mặc định «Nhân viên». */
    private Long positionId;

    /** Tuỳ chọn — mặc định hôm nay. */
    private LocalDate hireDate;

    /** Tuỳ chọn — mặc định 0. */
    private BigDecimal baseSalary;

    /** Mặc định ACTIVE nếu null. Tab thử việc gửi PROBATION/INTERN. */
    private EmployeeStatus status;

    /** TTG / BTG — mặc định FULL_TIME. */
    private EmploymentType employmentType;

    /** Hồ sơ nhân lực mở rộng (mã chấm công bắt buộc khi tạo nhanh). */
    private WorkforceDetailsRequest workforce;
}
