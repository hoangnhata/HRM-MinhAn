package com.minhan.hrm.dto.nursingdaily;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

@Data
public class NursingDailyReportUpsertRequest {

    @NotNull
    private Long departmentId;

    @NotNull
    private LocalDate reportDate;

    @NotNull @Min(0)
    private Integer totalStaff;

    @NotNull @Min(0)
    private Integer workingStaff;

    @NotNull @Min(0)
    private Integer plannedLeave;

    @NotNull @Min(0)
    private Integer unplannedLeave;

    @NotNull @Min(0)
    private Integer maternityLeave;

    @NotNull @Min(0)
    private Integer longLeave;

    @NotNull @Min(0)
    private Integer dutyAfternoonOff;

    @NotNull @Min(0)
    private Integer externalMission;

    @NotNull @Min(0)
    private Integer inpatients;

    @NotNull @Min(0)
    private Integer outpatients;

    @NotNull @Min(0)
    private Integer paraclinical;

    @NotNull @Min(0)
    private Integer surgery;

    @NotNull @Min(0)
    private Integer dischargedYesterday;

    @NotNull @Min(0)
    private Integer actualBeds;

    @NotNull @Min(0)
    private Integer plannedBeds;

    @NotNull @Min(0)
    private Integer inpatientTreatmentDays;

    @NotNull @Min(0)
    private Integer falls;

    @NotNull @Min(0)
    private Integer newPressureUlcers;

    @NotNull @Min(0)
    private Integer idMixups;

    @NotNull @Min(0)
    private Integer medicationErrors;

    /** true = gửi / giữ trạng thái đã gửi; false = lưu nháp */
    private boolean submit = true;
}
