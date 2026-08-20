package com.minhan.hrm.controller;

import com.minhan.hrm.dto.evaluation.NursingEvaluationReviewRequest;
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
@RequestMapping("/j1-api/v1/nursing-evaluations")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Nursing evaluations", description = "Đánh giá NV khối ĐD — Trưởng khoa lập → Trưởng phòng ĐD → HCNS → Giám đốc")
public class NursingEvaluationController {

    private final NursingEvaluationService nursingEvaluationService;

    @GetMapping("/templates/{code}")
    @Operation(summary = "Lấy mẫu tiêu chí (để hiển thị form)")
    public Map<String, Object> template(@PathVariable String code) {
        return nursingEvaluationService.getTemplateForUi(code);
    }

    @GetMapping("/employees/{employeeId}")
    @Operation(summary = "Lịch sử đánh giá theo nhân viên")
    public List<Map<String, Object>> list(@PathVariable Long employeeId) {
        return nursingEvaluationService.listForEmployee(employeeId);
    }

    @GetMapping("/period-status")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HR2','HEAD_DEPARTMENT','HEAD_NURSING','DIRECTOR')")
    @Operation(summary = "Trạng thái phiếu đánh giá trong tháng (khối ĐD)")
    public List<Map<String, Object>> periodStatus(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam String templateCode) {
        return nursingEvaluationService.listPeriodEvaluationStatus(year, month, templateCode);
    }

    @GetMapping("/summary")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HR2','HEAD_NURSING','DIRECTOR')")
    @Operation(summary = "Tổng hợp xếp loại theo tháng — khối ĐD")
    public List<Map<String, Object>> monthlySummary(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam String templateCode) {
        return nursingEvaluationService.listMonthlySummary(year, month, templateCode);
    }

    @GetMapping("/pending")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','HEAD_NURSING','DIRECTOR')")
    @Operation(summary = "Danh sách phiếu chờ duyệt (Trưởng phòng ĐD / HCNS / Giám đốc)")
    public List<Map<String, Object>> pending() {
        return nursingEvaluationService.listPending();
    }

    @GetMapping("/history")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','HEAD_NURSING','DIRECTOR')")
    @Operation(summary = "Lịch sử phiếu đã duyệt / từ chối ở bước của người xem")
    public List<Map<String, Object>> history() {
        return nursingEvaluationService.listHistory();
    }

    @GetMapping("/mine")
    @Operation(summary = "Phiếu đánh giá đã duyệt của chính tôi (sau khi Giám đốc duyệt)")
    public List<Map<String, Object>> mine() {
        return nursingEvaluationService.listMineApproved();
    }

    @GetMapping("/records/{evaluationId}")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HR2','HEAD_DEPARTMENT','HEAD_NURSING','DIRECTOR','EMPLOYEE')")
    @Operation(summary = "Chi tiết một phiếu đánh giá (NV chỉ xem phiếu đã duyệt của mình)")
    public Map<String, Object> recordDetail(@PathVariable Long evaluationId) {
        return nursingEvaluationService.getRecordDetail(evaluationId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Trưởng khoa / ĐDT khoa lập + chấm. submitForReview=true → gửi Trưởng phòng ĐD")
    public Map<String, Object> submit(@Valid @RequestBody NursingEvaluationSubmitRequest request) {
        return nursingEvaluationService.submit(request);
    }

    @PostMapping("/{id}/nursing-head-review")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Trưởng phòng Điều dưỡng duyệt + ký")
    public Map<String, Object> nursingHeadReview(
            @PathVariable Long id,
            @Valid @RequestBody NursingEvaluationReviewRequest body) {
        return nursingEvaluationService.nursingHeadReview(id, body);
    }

    @PostMapping("/{id}/hr-review")
    @PreAuthorize("hasAnyRole('ADMIN','HR2')")
    @Operation(summary = "HCNS duyệt / từ chối + ký")
    public Map<String, Object> hrReview(
            @PathVariable Long id,
            @Valid @RequestBody NursingEvaluationReviewRequest body) {
        return nursingEvaluationService.hrReview(id, body);
    }

    @PostMapping("/{id}/director-review")
    @PreAuthorize("hasAnyRole('ADMIN','DIRECTOR')")
    @Operation(summary = "Giám đốc duyệt / từ chối + ký")
    public Map<String, Object> directorReview(
            @PathVariable Long id,
            @Valid @RequestBody NursingEvaluationReviewRequest body) {
        return nursingEvaluationService.directorReview(id, body);
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Thu hồi phiếu đánh giá (người lập hoặc ADMIN)")
    public Map<String, Object> cancel(@PathVariable Long id) {
        return nursingEvaluationService.cancel(id);
    }
}
