package com.minhan.hrm.dto.training;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class TrainingProposalCreateRequest {

    @NotNull
    private Long employeeId;

    @NotBlank
    @Size(max = 255)
    private String proposingDepartment;

    @NotBlank
    @Size(max = 500)
    private String courseName;

    @NotBlank
    @Size(max = 500)
    private String location;

    @NotBlank
    @Size(max = 255)
    private String plannedPeriod;

    @Size(max = 255)
    private String tuitionFee;

    @NotBlank
    @Size(max = 2000)
    private String trainingGoal;

    @NotBlank
    @Size(max = 2000)
    private String reason;

    /** Cam kết của nhân viên — bắt buộc xác nhận */
    private Boolean employeeCommitmentAck;

    /** Cam kết của Khoa/Phòng — bắt buộc xác nhận */
    private Boolean departmentCommitmentAck;
}
