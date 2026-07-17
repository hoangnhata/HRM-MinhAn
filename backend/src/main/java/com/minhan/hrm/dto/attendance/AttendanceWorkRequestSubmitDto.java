package com.minhan.hrm.dto.attendance;

import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.AttendanceShiftScope;
import com.minhan.hrm.entity.AttendanceUpdateKind;
import com.minhan.hrm.entity.ExplanationKind;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalTime;

@Data
public class AttendanceWorkRequestSubmitDto {

    @NotNull
    private AttendanceRequestType requestType;

    /** Nhân viên được điều động — bắt buộc với DEPLOYMENT (trưởng tạo cho người khác). */
    private Long employeeId;

    @NotNull
    private LocalDate workDate;

    /** Ngày kết thúc — bắt buộc với LEAVE / UNPAID_LEAVE / BUSINESS_TRIP. */
    private LocalDate endDate;

    @NotNull
    private AttendanceShiftScope shiftScope;

    private AttendanceUpdateKind updateKind;

    @NotBlank
    private String reason;

    /** Địa điểm công tác — bắt buộc với BUSINESS_TRIP. */
    private String location;

    private LocalTime requestedStart;

    private LocalTime requestedEnd;

    /** Ca chiều — chỉ dùng khi bổ sung cả ngày. */
    private LocalTime requestedAfternoonStart;

    private LocalTime requestedAfternoonEnd;

    private ExplanationKind explanationKind;

    /** Giờ vào thực tế (đi muộn) — legacy / 1 mốc. */
    private LocalTime explainedTime;

    /** Giờ ra thực tế (về sớm) — legacy / 1 mốc. */
    private LocalTime explainedDepartureTime;

    /** Giải trình từng khung (ưu tiên khi có). */
    private LocalTime explainedMorningIn;
    private LocalTime explainedMorningOut;
    private LocalTime explainedAfternoonIn;
    private LocalTime explainedAfternoonOut;
}
