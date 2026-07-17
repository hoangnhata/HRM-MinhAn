package com.minhan.hrm.dto.account;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class AccountProfileUpdateRequest {

    @Email
    private String email;

    private String phone;
    private String address;

    @Size(max = 200)
    private String fullName;

    /** yyyy-MM-dd — đồng bộ ERP DOB */
    private String dateOfBirth;

    /** URL / base64 avatar ERP (có thể để trống) */
    private String userAvatar;

    /** Khi có hồ sơ nhân viên HRM — đổi đơn vị làm việc (không ghi ERP) */
    private Long departmentId;
}
