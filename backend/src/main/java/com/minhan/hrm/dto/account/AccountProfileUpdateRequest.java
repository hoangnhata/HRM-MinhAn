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

    /** Khi có hồ sơ nhân viên — đổi đơn vị làm việc */
    private Long departmentId;
}
