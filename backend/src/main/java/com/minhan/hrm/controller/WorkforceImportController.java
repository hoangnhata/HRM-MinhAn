package com.minhan.hrm.controller;

import com.minhan.hrm.dto.salary.SalaryImportResultDto;
import com.minhan.hrm.dto.attendance.CheckInOutSyncStatusDto;
import com.minhan.hrm.dto.attendance.ChamcongSyncScheduleUpdateRequest;
import com.minhan.hrm.service.CheckInOutImportService;
import com.minhan.hrm.service.CheckInOutSyncService;
import com.minhan.hrm.service.SalaryImportService;
import com.minhan.hrm.service.WorkforceExcelImportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/import")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Import", description = "Nhập Excel nhân lực & dữ liệu chấm công")
public class WorkforceImportController {

    private final WorkforceExcelImportService workforceExcelImportService;
    private final CheckInOutImportService checkInOutImportService;
    private final CheckInOutSyncService checkInOutSyncService;
    private final SalaryImportService salaryImportService;

    @PostMapping(value = "/workforce", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Import file TỔNG HỢP THÔNG TIN NHÂN LỰC (.xlsx) — sheet chính thức + thử việc/thực tập")
    public Map<String, Object> importWorkforce(@RequestPart("file") MultipartFile file) {
        return workforceExcelImportService.importWorkforceExcel(file);
    }

    @PostMapping(value = "/check-in-out", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Import file SQL CheckInOut từ máy chấm công — gộp theo ngày vào bảng công")
    public Map<String, Object> importCheckInOut(@RequestPart("file") MultipartFile file) {
        return checkInOutImportService.importCheckInOutSql(file);
    }

    @GetMapping("/check-in-out/sync-status")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Trạng thái kết nối SQL Server máy chấm công")
    public CheckInOutSyncStatusDto checkInOutSyncStatus() {
        return checkInOutSyncService.getStatus();
    }

    @PutMapping("/check-in-out/sync-schedule")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cấu hình giờ tự động đồng bộ máy chấm công hàng ngày")
    public CheckInOutSyncStatusDto updateCheckInOutSyncSchedule(
            @Valid @RequestBody ChamcongSyncScheduleUpdateRequest request) {
        return checkInOutSyncService.updateSchedule(request);
    }

    @PostMapping("/check-in-out/sync")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Đồng bộ dữ liệu quẹt thẻ từ SQL Server chamcong.CheckInOut")
    public Map<String, Object> syncCheckInOut(
            @RequestParam(required = false) LocalDate fromDate) {
        if (fromDate != null) {
            return checkInOutSyncService.syncFromDate(fromDate);
        }
        return checkInOutSyncService.syncRecent();
    }

    @PostMapping(value = "/salary-seniority", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Import thâm niên / cấu hình lương từ thâm niên nv.xlsx")
    public SalaryImportResultDto importSalarySeniority(@RequestPart("file") MultipartFile file) {
        return salaryImportService.importSeniorityExcel(file);
    }

    @PostMapping(value = "/salary-scale", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Import thang bảng lương từ thang bảng lương ma.xlsx")
    public SalaryImportResultDto importSalaryScale(@RequestPart("file") MultipartFile file) {
        return salaryImportService.importScaleExcel(file);
    }
}
