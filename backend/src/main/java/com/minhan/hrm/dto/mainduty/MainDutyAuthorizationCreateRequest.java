package com.minhan.hrm.dto.mainduty;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDate;

@Data
public class MainDutyAuthorizationCreateRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private LocalDate accompanyingFrom;

    @NotNull
    private LocalDate accompanyingTo;

    @NotNull
    private LocalDate effectiveFrom;

    @Size(max = 50)
    private String phone;

    @Size(max = 500)
    private String address;

    @Size(max = 20)
    private String gender;

    @Size(max = 255)
    private String degree;

    @Size(max = 2000)
    private String reason;
}
