package com.minhan.hrm.dto.probation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDate;
import java.util.Map;

@Data
public class ProbationConversionCreateRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private LocalDate officialDate;

    @NotBlank
    @Size(max = 1000)
    private String reason;

    /** DOCTOR | NURSE | STAFF — nếu bỏ trống hệ thống tự phân loại */
    private String formType;

    @Size(max = 2000)
    private String mentorComment;

    @Size(max = 2000)
    private String headDeptComment;

    /** Chỉ mẫu điều dưỡng */
    @Size(max = 2000)
    private String wardNurseHeadComment;

    /** Chỉ mẫu điều dưỡng */
    @Size(max = 2000)
    private String hospitalNurseHeadComment;

    /** Điểm theo mã tiêu chí — bắt buộc với DOCTOR/NURSE */
    private Map<String, Integer> scores;
}
