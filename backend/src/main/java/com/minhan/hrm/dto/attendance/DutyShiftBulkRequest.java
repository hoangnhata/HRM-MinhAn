package com.minhan.hrm.dto.attendance;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDate;
import java.util.List;

@Getter
@Setter
public class DutyShiftBulkRequest {

    @NotNull
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate workDate;

    /** Ghi chú chung (tuỳ chọn) áp dụng cho mọi dòng. */
    private String note;

    @NotEmpty
    @Valid
    private List<DutyShiftBulkItem> items;

    @Getter
    @Setter
    public static class DutyShiftBulkItem {

        @NotNull
        private Long employeeId;

        @NotBlank
        private String shiftTypeCode;

        /** Để trống — hệ thống tự nhận diện theo chức vụ. */
        private String roleTierCode;
    }
}
