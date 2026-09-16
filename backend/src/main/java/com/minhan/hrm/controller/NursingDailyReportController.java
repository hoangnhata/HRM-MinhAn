package com.minhan.hrm.controller;

import com.minhan.hrm.dto.nursingdaily.NursingDailyReportUpsertRequest;
import com.minhan.hrm.service.NursingDailyReportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/nursing-daily-reports")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(
        name = "Nursing daily reports",
        description = "Báo cáo ĐD hằng ngày — Điều dưỡng trưởng khoa nhập; Trưởng phòng ĐD xem/sửa toàn bộ")
@PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING','HEAD_DEPARTMENT')")
public class NursingDailyReportController {

    private final NursingDailyReportService reportService;

    @GetMapping("/departments")
    @Operation(summary = "Danh sách khoa được phép (khoa mình hoặc toàn khối ĐD)")
    public List<Map<String, Object>> departments() {
        return reportService.listDepartments();
    }

    @GetMapping
    @Operation(summary = "Danh sách khoa + trạng thái nộp theo ngày")
    public List<Map<String, Object>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) Long departmentId) {
        return reportService.listForDate(date, departmentId);
    }

    @GetMapping("/month")
    @Operation(summary = "Danh sách ngày trong tháng (đến hôm nay) + trạng thái nộp — theo dõi chưa nhập")
    public List<Map<String, Object>> listMonth(
            @RequestParam String yearMonth,
            @RequestParam(required = false) Long departmentId) {
        java.time.YearMonth ym;
        try {
            ym = java.time.YearMonth.parse(yearMonth);
        } catch (Exception e) {
            throw new IllegalArgumentException("yearMonth phải dạng YYYY-MM");
        }
        return reportService.listForMonth(ym, departmentId);
    }

    @GetMapping("/by")
    @Operation(summary = "Lấy báo cáo theo khoa và ngày (null nếu chưa có)")
    public Map<String, Object> byDepartmentAndDate(
            @RequestParam Long departmentId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return reportService.getByDepartmentAndDate(departmentId, date);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Chi tiết báo cáo")
    public Map<String, Object> get(@PathVariable Long id) {
        return reportService.getById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Tạo báo cáo mới (1 khoa / 1 ngày)")
    public Map<String, Object> create(@Valid @RequestBody NursingDailyReportUpsertRequest request) {
        return reportService.create(request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Cập nhật báo cáo đã có")
    public Map<String, Object> update(
            @PathVariable Long id,
            @Valid @RequestBody NursingDailyReportUpsertRequest request) {
        return reportService.update(id, request);
    }

    @PostMapping("/{id}/recall")
    @Operation(summary = "Thu hồi báo cáo đã gửi về nháp (Trưởng khoa trong 1 ngày; Trưởng phòng ĐD / ADMIN mọi lúc)")
    public Map<String, Object> recall(@PathVariable Long id) {
        return reportService.recall(id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Xoá báo cáo (chỉ ADMIN)")
    public void delete(@PathVariable Long id) {
        reportService.delete(id);
    }
}
