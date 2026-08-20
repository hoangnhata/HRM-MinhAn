package com.minhan.hrm.dto.seminar;

import com.minhan.hrm.entity.AttendanceShiftScope;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDate;

@Data
public class SeminarProposalCreateRequest {

    @NotNull
    private Long employeeId;

    @NotBlank
    @Size(max = 255)
    private String proposingDepartment;

    @NotBlank
    @Size(max = 500)
    private String seminarName;

    @NotBlank
    @Size(max = 500)
    private String location;

    @NotNull
    private LocalDate startDate;

    @NotNull
    private LocalDate endDate;

    @NotNull
    private AttendanceShiftScope attendanceScope;

    @NotBlank
    @Size(max = 2000)
    private String reason;

    private Boolean employeeCommitmentAck;

    private Boolean departmentCommitmentAck;
}
