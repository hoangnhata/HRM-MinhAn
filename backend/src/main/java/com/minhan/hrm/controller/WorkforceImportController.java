package com.minhan.hrm.controller;

import com.minhan.hrm.dto.salary.SalaryImportResultDto;
import com.minhan.hrm.dto.attendance.CheckInOutSyncStatusDto;
import com.minhan.hrm.dto.attendance.ChamcongSyncScheduleUpdateRequest;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.service.AccompanyingDutyImportService;
import com.minhan.hrm.service.AttendanceCodeSyncService;
import com.minhan.hrm.service.CheckInOutImportService;
import com.minhan.hrm.service.CheckInOutSyncService;
import com.minhan.hrm.service.SalaryImportService;
import com.minhan.hrm.service.WorkforceExcelExportService;
import com.minhan.hrm.service.WorkforceExcelImportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
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

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/import")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Import", description = "Nhập Excel nhân lực & dữ liệu chấm công")
public class WorkforceImportController {

    private final WorkforceExcelImportService workforceExcelImportService;
    private final AccompanyingDutyImportService accompanyingDutyImportService;
    private final WorkforceExcelExportService workforceExcelExportService;
    private final CheckInOutImportService checkInOutImportService;
    private final CheckInOutSyncService checkInOutSyncService;
    private final AttendanceCodeSyncService attendanceCodeSyncService;
    private final SalaryImportService salaryImportService;

    @PostMapping(value = "/workforce", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Import file NHÂN LỰC BỆNH VIỆN MINH AN (.xlsx) — TTG/BTG + thâm niên/thang lương + thử việc")
    public Map<String, Object> importWorkforce(@RequestPart("file") MultipartFile file) {
        return workforceExcelImportService.importWorkforceExcel(file);
    }

    @PostMapping(value = "/accompanying-duty", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Import danh sách nhân viên trực kèm (.xlsx) — NV trong file chỉ được ca TK; còn lại được trực bình thường")
    public Map<String, Object> importAccompanyingDuty(@RequestPart("file") MultipartFile file) {
        return accompanyingDutyImportService.importAccompanyingDutyList(file);
    }

    @GetMapping("/workforce/export")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_NURSING')")
    @Operation(summary = "Xuất Excel nhân lực (chính thức + thử việc). scope=HOSPITAL (mặc định) hoặc NURSING (khối Trưởng phòng ĐD)")
    public ResponseEntity<byte[]> exportWorkforce(
            @RequestParam(name = "scope", defaultValue = "HOSPITAL") String scope,
            Authentication authentication) {
        boolean nursing = "NURSING".equalsIgnoreCase(scope);
        boolean adminOrHr = authentication.getAuthorities().stream().anyMatch(a -> {
            String role = a.getAuthority();
            return "ROLE_ADMIN".equals(role) || "ROLE_HR".equals(role);
        });
        if (!nursing && !adminOrHr) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Trưởng phòng Điều dưỡng chỉ xuất Excel khối điều dưỡng.");
        }
        byte[] body = workforceExcelExportService.exportWorkforceExcel(nursing);
        String filename = (nursing ? "NHAN-LUC-KHOI-DIEU-DUONG-" : "NHAN-LUC-BENH-VIEN-MINH-AN-")
                + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmm"))
                + ".xlsx";
        ContentDisposition cd = ContentDisposition.attachment()
                .filename(filename, StandardCharsets.UTF_8)
                .build();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .contentType(MediaType.parseMediaType(
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(body);
    }

    @PostMapping(value = "/check-in-out", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
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

    @PostMapping("/attendance-codes/sync")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Đồng bộ mã chấm công từ chamcong.dbo.UserInfo cho NV còn thiếu mã")
    public Map<String, Object> syncAttendanceCodes() {
        return attendanceCodeSyncService.syncMissingAttendanceCodes();
    }

    @PostMapping(value = "/salary-scale", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Import thang bảng lương (định nghĩa bậc) từ file riêng — tùy chọn")
    public SalaryImportResultDto importSalaryScale(@RequestPart("file") MultipartFile file) {
        return salaryImportService.importScaleExcel(file);
    }
}
