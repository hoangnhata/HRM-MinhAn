package com.minhan.hrm.controller;

import com.minhan.hrm.dto.evaluation.NursingEvaluationChannelSubmitRequest;
import com.minhan.hrm.dto.evaluation.NursingEvaluationSubmitRequest;
import com.minhan.hrm.service.NursingEvaluationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/nursing-evaluations")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Nursing evaluations", description = "Đánh giá ĐD-KTV-HS — xếp loại theo tháng (MA 2026)")
public class NursingEvaluationController {

    private final NursingEvaluationService nursingEvaluationService;

    @GetMapping("/templates/{code}")
    @Operation(summary = "Lấy mẫu tiêu chí (để hiển thị form)")
    public Map<String, Object> template(@PathVariable String code) {
        return nursingEvaluationService.getTemplateForUi(code);
    }

    @GetMapping("/employees/{employeeId}")
    @Operation(summary = "Lịch sử đánh giá (ADMIN/HR, NV xem mình, trưởng khoa/ĐDT xem cùng phòng ban)")
    public List<Map<String, Object>> list(@PathVariable Long employeeId) {
        return nursingEvaluationService.listForEmployee(employeeId);
    }

    @GetMapping("/period-status")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Phiếu MA trong tháng: đã có điểm từng kênh (lọc danh sách NV)")
    public List<Map<String, Object>> periodStatus(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam String templateCode) {
        return nursingEvaluationService.listPeriodEvaluationStatus(year, month, templateCode);
    }

    @GetMapping("/summary")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Tổng hợp xếp loại theo tháng — P.HCNS / ADMIN")
    public List<Map<String, Object>> monthlySummary(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam String templateCode) {
        return nursingEvaluationService.listMonthlySummary(year, month, templateCode);
    }

    @GetMapping("/records/{evaluationId}")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Chi tiết một bản đánh giá (đủ tiêu chí + điểm) — HCNS / ADMIN")
    public Map<String, Object> recordDetail(@PathVariable Long evaluationId) {
        return nursingEvaluationService.getRecordDetail(evaluationId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "ADMIN: lưu đủ 2 cột (Khoa phòng + ĐDT) một lần (ghi đè nếu trùng kỳ + mẫu)")
    public Map<String, Object> submit(@Valid @RequestBody NursingEvaluationSubmitRequest request) {
        return nursingEvaluationService.submit(request);
    }

    @PostMapping("/channel")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Lưu một cột (Trưởng khoa / ĐDT: 70 điểm; HCNS: 30 điểm) — gộp dần theo tháng")
    public Map<String, Object> submitChannel(@Valid @RequestBody NursingEvaluationChannelSubmitRequest request) {
        return nursingEvaluationService.submitChannel(request);
    }
}
