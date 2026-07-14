package com.minhan.hrm.dto.employee;

import lombok.Value;

import java.time.LocalDate;

@Value
public class ConfirmOfficialRequest {
    /** Ngày chính thức; mặc định hôm nay nếu không gửi. */
    LocalDate officialDate;
}
