package com.minhan.hrm.controller;

import com.minhan.hrm.dto.attendance.ForgotPenaltyConfigRequest;
import com.minhan.hrm.dto.attendance.LatePenaltyConfigUpdateRequest;
import com.minhan.hrm.dto.attendance.AttendanceNotifyRequest;
import com.minhan.hrm.dto.attendance.AttendanceRequest;
import com.minhan.hrm.dto.attendance.AttendanceReviewDto;
import com.minhan.hrm.dto.attendance.AttendanceShiftConfigUpdateRequest;
import com.minhan.hrm.dto.attendance.AttendanceWorkRequestSubmitDto;
import com.minhan.hrm.dto.attendance.DutyShiftBulkRequest;
import com.minhan.hrm.dto.attendance.DutyShiftUpsertRequest;
import com.minhan.hrm.dto.attendance.CongHoSupplementRequest;
import com.minhan.hrm.dto.attendance.QuangTrungSupplementBulkRequest;
import com.minhan.hrm.dto.attendance.QuangTrungSupplementRequest;
import com.minhan.hrm.dto.attendance.HolidayWorkDaysUpdateRequest;
import com.minhan.hrm.dto.attendance.EmployeeContinuousShiftRequest;
import com.minhan.hrm.entity.AttendanceShiftSeason;
import com.minhan.hrm.service.ForgotPenaltyConfigService;
import com.minhan.hrm.service.HolidayWorkDayService;
import com.minhan.hrm.service.LatePenaltyConfigService;
import com.minhan.hrm.service.AttendanceReportExcelService;
import com.minhan.hrm.service.AttendanceService;
import com.minhan.hrm.service.AttendanceShiftScheduleService;
import com.minhan.hrm.service.AttendanceSummaryService;
import com.minhan.hrm.service.AttendanceWorkRequestService;
import com.minhan.hrm.service.DutyShiftService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/attendance")
@RequiredArgsConstructor
@Slf4j
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Attendance", description = "Bảng công")
public class AttendanceController {

    private final AttendanceService attendanceService;
    private final AttendanceSummaryService summaryService;
    private final AttendanceReportExcelService reportExcelService;
    private final AttendanceWorkRequestService workRequestService;
    private final AttendanceShiftScheduleService shiftScheduleService;
    private final ForgotPenaltyConfigService forgotPenaltyConfigService;
    private final LatePenaltyConfigService latePenaltyConfigService;
    private final DutyShiftService dutyShiftService;
    private final HolidayWorkDayService holidayWorkDayService;

    @GetMapping("/penalty/forgot-config")
    @Operation(summary = "Cấu hình phạt quên chấm công")
    public Map<String, Object> forgotPenaltyConfig() {
        return forgotPenaltyConfigService.getConfigView();
    }

    @PutMapping("/penalty/forgot-config")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cập nhật cấu hình phạt quên chấm công")
    public Map<String, Object> updateForgotPenaltyConfig(@Valid @RequestBody ForgotPenaltyConfigRequest body) {
        return forgotPenaltyConfigService.updateConfig(body);
    }

    @GetMapping("/penalty/late-config")
    @Operation(summary = "Cấu hình phạt đi muộn / về sớm")
    public Map<String, Object> latePenaltyConfig() {
        return latePenaltyConfigService.getConfigView();
    }

    @PutMapping("/penalty/late-config")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cập nhật cấu hình phạt đi muộn / về sớm")
    public Map<String, Object> updateLatePenaltyConfig(@Valid @RequestBody LatePenaltyConfigUpdateRequest body) {
        return latePenaltyConfigService.updateConfig(body);
    }

    @GetMapping("/holiday-work-days")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Danh sách ngày lễ (đi làm = 2 công) theo tháng")
    public Map<String, Object> holidayWorkDays(
            @RequestParam int year,
            @RequestParam int month) {
        return holidayWorkDayService.listForMonth(year, month);
    }

    @PutMapping("/holiday-work-days")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cập nhật ngày lễ trong tháng (đi làm = 2 công)")
    public Map<String, Object> updateHolidayWorkDays(@Valid @RequestBody HolidayWorkDaysUpdateRequest body) {
        return holidayWorkDayService.replaceMonth(body);
    }

    @GetMapping("/schedule")
    @Operation(summary = "Lịch ca theo ngày (tự nhận mùa hè/đông)")
    public Map<String, Object> schedule(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) Long employeeId) {
        LocalDate ref = date != null ? date : LocalDate.now();
        return shiftScheduleService.infoForDate(ref, employeeId);
    }

    @GetMapping("/schedule/config")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cấu hình lịch ca mùa hè/đông")
    public Map<String, Object> scheduleConfig() {
        return shiftScheduleService.getConfigAdminView();
    }

    @PutMapping("/schedule/config/{season}")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cập nhật lịch ca theo mùa (SUMMER hoặc WINTER)")
    public Map<String, Object> updateScheduleConfig(
            @PathVariable AttendanceShiftSeason season,
            @Valid @RequestBody AttendanceShiftConfigUpdateRequest body) {
        return shiftScheduleService.updateSeasonConfig(season, body);
    }

    @GetMapping("/employees/{employeeId}/schedule/config")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cấu hình lịch ca riêng của một nhân viên (fallback cấu hình chung)")
    public Map<String, Object> employeeScheduleConfig(@PathVariable Long employeeId) {
        return shiftScheduleService.getEmployeeConfigAdminView(employeeId);
    }

    @PutMapping("/employees/{employeeId}/schedule/config/{season}")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cập nhật lịch ca riêng của một nhân viên")
    public Map<String, Object> updateEmployeeScheduleConfig(
            @PathVariable Long employeeId,
            @PathVariable AttendanceShiftSeason season,
            @Valid @RequestBody AttendanceShiftConfigUpdateRequest body) {
        return shiftScheduleService.updateEmployeeSeasonConfig(employeeId, season, body);
    }

    @PutMapping("/schedule/config/{season}/apply-all")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Áp dụng cấu hình ca cho tất cả nhân viên đang làm việc")
    public Map<String, Object> applyScheduleConfigToAll(
            @PathVariable AttendanceShiftSeason season,
            @Valid @RequestBody AttendanceShiftConfigUpdateRequest body) {
        return shiftScheduleService.applySeasonConfigToAll(season, body);
    }

    @GetMapping("/employees/{employeeId}/continuous-shift")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Danh sách ngày ca thông tầm của nhân viên trong tháng")
    public Map<String, Object> getContinuousShift(
            @PathVariable Long employeeId,
            @RequestParam int year,
            @RequestParam int month) {
        return shiftScheduleService.getEmployeeContinuousShiftDays(employeeId, year, month);
    }

    @PutMapping("/employees/{employeeId}/continuous-shift")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cấu hình ngày ca thông tầm trong tháng (thay thế danh sách ngày)")
    public Map<String, Object> setContinuousShift(
            @PathVariable Long employeeId,
            @Valid @RequestBody EmployeeContinuousShiftRequest body) {
        Map<String, Object> result = new LinkedHashMap<>(shiftScheduleService.setEmployeeContinuousShift(
                employeeId, body.getYear(), body.getMonth(), body.getContinuousShift(), body.getDates()));
        try {
            int recalculated = attendanceService.recalculateEmployeeMonth(
                    employeeId, body.getYear(), body.getMonth());
            result.put("recalculated", recalculated);
        } catch (Exception e) {
            log.warn("Ca thông tầm đã lưu nhưng tính lại công thất bại — employee {} {}/{}",
                    employeeId, body.getMonth(), body.getYear(), e);
            result.put("recalculated", 0);
            result.put("recalculateWarning", "Đã lưu ca thông tầm nhưng chưa tính lại được bảng công.");
        }
        return result;
    }

    @PutMapping("/employees/{employeeId}/young-child")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Bật/tắt chế độ nuôi con nhỏ (giảm 1 giờ/ngày, tối thiểu 7h = 1 công)")
    public Map<String, Object> setYoungChild(
            @PathVariable Long employeeId,
            @Valid @RequestBody com.minhan.hrm.dto.attendance.EmployeeYoungChildRequest body) {
        Map<String, Object> result = new LinkedHashMap<>(shiftScheduleService.setEmployeeYoungChild(
                employeeId, body.getYear(), body.getMonth(), body.getYoungChild()));
        try {
            int recalculated = attendanceService.recalculateEmployeeMonth(
                    employeeId, body.getYear(), body.getMonth());
            result.put("recalculated", recalculated);
        } catch (Exception e) {
            log.warn("Nuôi con nhỏ đã lưu nhưng tính lại công thất bại — employee {} {}/{}",
                    employeeId, body.getMonth(), body.getYear(), e);
            result.put("recalculated", 0);
            result.put("recalculateWarning", "Đã lưu chế độ nuôi con nhỏ nhưng chưa tính lại được bảng công.");
        }
        return result;
    }

    @GetMapping("/employees/{employeeId}")
    @Operation(summary = "Bảng công theo khoảng ngày")
    public List<Map<String, Object>> range(
            @PathVariable Long employeeId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return attendanceService.listRange(employeeId, from, to);
    }

    @GetMapping("/employees/{employeeId}/summary")
    public Map<String, Object> employeeSummary(
            @PathVariable Long employeeId,
            @RequestParam int year,
            @RequestParam int month) {
        return summaryService.employeeMonthSummary(employeeId, year, month);
    }

    @GetMapping("/employees/{employeeId}/detail")
    public Map<String, Object> employeeDetail(
            @PathVariable Long employeeId,
            @RequestParam int year,
            @RequestParam int month) {
        return summaryService.employeeMonthDetail(employeeId, year, month);
    }

    @GetMapping("/summary")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    public List<Map<String, Object>> departmentSummary(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam(required = false) Long departmentId) {
        return summaryService.departmentMonthSummary(year, month, departmentId);
    }

    @GetMapping("/report/excel")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Xuất báo cáo công toàn viện theo tháng ra file Excel")
    public ResponseEntity<byte[]> exportMonthlyReport(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam(required = false) Long departmentId) {
        byte[] body = reportExcelService.buildMonthlyReport(year, month, departmentId);
        String filename = String.format("bao-cao-cong-%d-%02d.xlsx", year, month);
        ContentDisposition cd = ContentDisposition.attachment()
                .filename(filename, StandardCharsets.UTF_8)
                .build();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .contentType(MediaType.parseMediaType(
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(body);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Ghi nhận / cập nhật công")
    public Map<String, Object> upsert(@Valid @RequestBody AttendanceRequest request) {
        return attendanceService.upsert(request);
    }

    @PostMapping("/recalculate")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    public Map<String, Object> recalculate(@RequestParam int year, @RequestParam int month) {
        int n = attendanceService.recalculateMonth(year, month);
        return Map.of("recalculated", n);
    }

    @PostMapping("/employees/{employeeId}/recalculate")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Tính lại bảng công một nhân viên theo tháng")
    public Map<String, Object> recalculateEmployee(
            @PathVariable Long employeeId,
            @RequestParam int year,
            @RequestParam int month) {
        int n = attendanceService.recalculateEmployeeMonth(employeeId, year, month);
        return Map.of("recalculated", n, "employeeId", employeeId);
    }

    @PostMapping("/notify-month")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Gửi thông báo bảng công cho nhân viên")
    public void notifyMonth(@Valid @RequestBody AttendanceNotifyRequest request) {
        attendanceService.notifyEmployeeAboutMonth(
                request.getEmployeeId(), request.getYear(), request.getMonth());
    }

    @PostMapping("/requests")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> submitRequest(@Valid @RequestBody AttendanceWorkRequestSubmitDto dto) {
        return workRequestService.submit(dto);
    }

    @GetMapping("/requests/mine")
    public List<Map<String, Object>> myRequests() {
        return workRequestService.myRequests();
    }

    @GetMapping("/requests/pending")
    public List<Map<String, Object>> pendingRequests() {
        return workRequestService.pendingForReviewer();
    }

    @GetMapping("/requests/review-history")
    public List<Map<String, Object>> reviewHistoryRequests() {
        return workRequestService.reviewHistoryForReviewer();
    }

    @PostMapping("/requests/{id}/head-review")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    public Map<String, Object> headReview(@PathVariable Long id, @Valid @RequestBody AttendanceReviewDto dto) {
        return workRequestService.headReview(id, dto);
    }

    @PostMapping("/requests/{id}/hr-review")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    public Map<String, Object> hrReview(@PathVariable Long id, @Valid @RequestBody AttendanceReviewDto dto) {
        return workRequestService.hrReview(id, dto);
    }

    @PostMapping("/requests/{id}/withdraw")
    @ResponseStatus(HttpStatus.OK)
    @Operation(summary = "Thu hồi đơn công (người gửi, khi đang chờ duyệt)")
    public Map<String, Object> withdrawRequest(@PathVariable Long id) {
        return workRequestService.withdraw(id);
    }

    @GetMapping("/leave-balance")
    @Operation(summary = "Hạn mức nghỉ phép năm của nhân viên đang đăng nhập")
    public Map<String, Object> myLeaveBalance(@RequestParam(required = false) Integer year) {
        return workRequestService.myLeaveBalance(year);
    }

    @GetMapping("/employees/{employeeId}/leave-balance")
    @Operation(summary = "Hạn mức nghỉ phép năm theo nhân viên")
    public Map<String, Object> employeeLeaveBalance(
            @PathVariable Long employeeId,
            @RequestParam(required = false) Integer year) {
        return workRequestService.employeeLeaveBalance(employeeId, year);
    }

    @GetMapping("/duty-shifts/types")
    @Operation(summary = "Danh mục loại ca trực và mức thưởng theo vị trí")
    public List<Map<String, Object>> dutyShiftTypes() {
        return dutyShiftService.listShiftTypes();
    }

    @GetMapping("/employees/{employeeId}/duty-shifts")
    @Operation(summary = "Ca trực của nhân viên theo khoảng ngày")
    public List<Map<String, Object>> employeeDutyShifts(
            @PathVariable Long employeeId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return dutyShiftService.listForEmployee(employeeId, from, to);
    }

    @GetMapping("/employees/{employeeId}/duty-shifts/preview")
    @Operation(summary = "Xem trước tiền thưởng / công ca trực")
    public Map<String, Object> previewDutyShift(
            @PathVariable Long employeeId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate workDate,
            @RequestParam String shiftTypeCode,
            @RequestParam(required = false) String roleTierCode) {
        return dutyShiftService.preview(employeeId, workDate, shiftTypeCode, roleTierCode);
    }

    @PutMapping("/employees/{employeeId}/duty-shifts")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Trưởng phòng nhập / cập nhật ca trực cho nhân viên")
    public Map<String, Object> upsertDutyShift(
            @PathVariable Long employeeId,
            @Valid @RequestBody DutyShiftUpsertRequest body) {
        return dutyShiftService.upsert(
                employeeId, body.getWorkDate(), body.getShiftTypeCode(), body.getRoleTierCode(), body.getNote());
    }

    @PostMapping("/duty-shifts/bulk")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "HCNS/Admin nhập ca trực hàng loạt — mỗi NV một loại ca")
    public Map<String, Object> bulkUpsertDutyShifts(@Valid @RequestBody DutyShiftBulkRequest body) {
        List<Map<String, Object>> results = new ArrayList<>();
        int success = 0;
        int failure = 0;
        for (DutyShiftBulkRequest.DutyShiftBulkItem item : body.getItems()) {
            Long employeeId = item.getEmployeeId();
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("employeeId", employeeId);
            try {
                Map<String, Object> saved = dutyShiftService.upsert(
                        employeeId,
                        body.getWorkDate(),
                        item.getShiftTypeCode(),
                        item.getRoleTierCode(),
                        body.getNote());
                row.put("employeeName", saved.get("employeeName"));
                row.put("ok", true);
                row.put("message", "Đã lưu ca trực");
                success++;
            } catch (Exception e) {
                row.put("employeeName", dutyShiftService.employeeDisplayName(employeeId));
                row.put("ok", false);
                row.put("message", e.getMessage() != null ? e.getMessage() : "Lỗi không xác định");
                failure++;
            }
            results.add(row);
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("successCount", success);
        out.put("failureCount", failure);
        out.put("results", results);
        return out;
    }

    @DeleteMapping("/employees/{employeeId}/duty-shifts/{workDate}")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Xóa ca trực")
    public void deleteDutyShift(
            @PathVariable Long employeeId,
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate workDate) {
        dutyShiftService.delete(employeeId, workDate);
    }

    @PutMapping("/employees/{employeeId}/quang-trung-supplement")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "HCNS/Admin bổ sung hoặc sửa công Quang Trung — không trừ phạt quên chấm")
    public Map<String, Object> applyQuangTrungSupplement(
            @PathVariable Long employeeId,
            @Valid @RequestBody QuangTrungSupplementRequest body) {
        return attendanceService.applyQuangTrungSupplement(employeeId, body);
    }

    @PostMapping("/quang-trung-supplement/bulk")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "HCNS/Admin bổ sung công Quang Trung hàng loạt")
    public Map<String, Object> bulkQuangTrungSupplement(@Valid @RequestBody QuangTrungSupplementBulkRequest body) {
        QuangTrungSupplementRequest one = new QuangTrungSupplementRequest();
        one.setWorkDate(body.getWorkDate());
        one.setUpdateKind(body.getUpdateKind());
        one.setReason(body.getReason());
        one.setRequestedStart(body.getRequestedStart());
        one.setRequestedEnd(body.getRequestedEnd());
        one.setRequestedAfternoonStart(body.getRequestedAfternoonStart());
        one.setRequestedAfternoonEnd(body.getRequestedAfternoonEnd());

        List<Map<String, Object>> results = new ArrayList<>();
        int success = 0;
        int failure = 0;
        for (Long employeeId : body.getEmployeeIds()) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("employeeId", employeeId);
            try {
                Map<String, Object> saved = attendanceService.applyQuangTrungSupplement(employeeId, one);
                Object name = saved.get("employeeName");
                if (name == null) {
                    name = dutyShiftService.employeeDisplayName(employeeId);
                }
                row.put("employeeName", name);
                row.put("ok", true);
                row.put("message", "Đã lưu công Quang Trung");
                success++;
            } catch (Exception e) {
                row.put("employeeName", dutyShiftService.employeeDisplayName(employeeId));
                row.put("ok", false);
                row.put("message", e.getMessage() != null ? e.getMessage() : "Lỗi không xác định");
                failure++;
            }
            results.add(row);
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("successCount", success);
        out.put("failureCount", failure);
        out.put("results", results);
        return out;
    }

    @GetMapping("/employees/{employeeId}/quang-trung-supplement")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Xem công Quang Trung đã bổ sung theo ngày")
    public Map<String, Object> getQuangTrungSupplement(
            @PathVariable Long employeeId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate workDate) {
        return attendanceService.getQuangTrungSupplement(employeeId, workDate);
    }

    @DeleteMapping("/employees/{employeeId}/quang-trung-supplement/{workDate}")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Xóa công Quang Trung ngày đã chọn")
    public void deleteQuangTrungSupplement(
            @PathVariable Long employeeId,
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate workDate) {
        attendanceService.deleteQuangTrungSupplement(employeeId, workDate);
    }

    @PutMapping("/employees/{employeeId}/cong-ho-supplement")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "HCNS/Admin bổ sung hoặc sửa công hộ — không trừ phạt quên chấm")
    public Map<String, Object> applyCongHoSupplement(
            @PathVariable Long employeeId,
            @Valid @RequestBody CongHoSupplementRequest body) {
        return attendanceService.applyCongHoSupplement(employeeId, body);
    }

    @GetMapping("/employees/{employeeId}/cong-ho-supplement")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Xem công hộ đã bổ sung theo ngày")
    public Map<String, Object> getCongHoSupplement(
            @PathVariable Long employeeId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate workDate) {
        return attendanceService.getCongHoSupplement(employeeId, workDate);
    }

    @DeleteMapping("/employees/{employeeId}/cong-ho-supplement/{workDate}")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Xóa công hộ ngày đã chọn")
    public void deleteCongHoSupplement(
            @PathVariable Long employeeId,
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate workDate) {
        attendanceService.deleteCongHoSupplement(employeeId, workDate);
    }
}
