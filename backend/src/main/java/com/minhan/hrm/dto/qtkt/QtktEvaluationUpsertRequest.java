package com.minhan.hrm.dto.qtkt;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.util.Map;

@Data
public class QtktEvaluationUpsertRequest {

    @NotNull
    private Long employeeId;

    @NotBlank
    private String procedureCode;

    /** Mã lựa chọn kiểm tra — bắt buộc nếu quy trình có checkOptions trong template. */
    private String checkContextCode;

    /** Mã bệnh nhân — bắt buộc nếu quy trình requiresPatientCode (GDSK). */
    private String patientCode;

    @NotNull
    private LocalDate evalDate;

    /** stepId -> điểm đạt (0 .. maxPoints của bước) */
    @NotNull
    private Map<String, Double> scores;

    private String note;

    /** true = lưu và gửi Trưởng phòng ĐD */
    private boolean submit;
}
