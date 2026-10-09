package com.minhan.hrm.controller;

import com.minhan.hrm.dto.evaluation.NursingEvaluationReviewRequest;
import com.minhan.hrm.dto.evaluation.NursingEvaluationSubmitRequest;
import com.minhan.hrm.dto.evaluation.NursingEvaluationTemplateSaveRequest;
import com.minhan.hrm.service.NursingEvaluationExcelService;
import com.minhan.hrm.service.NursingEvaluationService;
import com.minhan.hrm.service.NursingEvaluationTemplateService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/nursing-evaluations")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Nursing evaluations", description = "Đánh giá NV khối ĐD — Trưởng khoa lập → Trưởng phòng ĐD → HCNS → Giám đốc")
public class NursingEvaluationController {

    private final NursingEvaluationService nursingEvaluationService;
    private final NursingEvaluationTemplateService templateService;
    private final NursingEvaluationExcelService excelService;

    @GetMapping("/templates/{code}")
    @Operation(summary = "Lấy mẫu tiêu chí (để hiển thị form)")
    public Map<String, Object> template(@PathVariable String code) {
        return nursingEvaluationService.getTemplateForUi(code);
    }

    @GetMapping("/templates/{code}/editor")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Mẫu đang dùng + thông tin phiên bản (màn hình chỉnh sửa mẫu)")
    public Map<String, Object> templateEditor(@PathVariable String code) {
        return templateService.editorState(code);
    }

    @PutMapping("/templates/{code}")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Lưu mẫu đánh giá (tạo phiên bản mới) — ADMIN / Trưởng phòng ĐD")
    public Map<String, Object> saveTemplate(
            @PathVariable String code,
            @Valid @RequestBody NursingEvaluationTemplateSaveRequest body) {
        return templateService.save(code, body);
    }

    @GetMapping("/templates/{code}/revisions")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Lịch sử phiên bản mẫu đánh giá")
    public List<Map<String, Object>> templateRevisions(@PathVariable String code) {
        return templateService.listRevisions(code);
    }

    @GetMapping("/templates/{code}/revisions/{revisionId}")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Nội dung một phiên bản mẫu (xem trước)")
    public Map<String, Object> templateRevision(@PathVariable String code, @PathVariable Long revisionId) {
        return templateService.revisionTemplate(code, revisionId);
    }

    @PostMapping("/templates/{code}/revisions/{revisionId}/restore")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Khôi phục một phiên bản cũ (tạo phiên bản mới)")
    public Map<String, Object> restoreTemplateRevision(
            @PathVariable String code,
            @PathVariable Long revisionId,
            @Valid @RequestBody NursingEvaluationTemplateSaveRequest body) {
        return templateService.restoreRevision(code, revisionId, body);
    }

    @PostMapping("/templates/{code}/reset")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Khôi phục mẫu gốc (tạo phiên bản mới)")
    public Map<String, Object> resetTemplate(
            @PathVariable String code,
            @Valid @RequestBody NursingEvaluationTemplateSaveRequest body) {
        return templateService.resetToDefault(code, body);
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

    @GetMapping("/summary/excel")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Xuất Excel thống kê xếp loại tháng — phiếu Trưởng phòng ĐD đã duyệt (ADMIN / Trưởng phòng ĐD)")
    public ResponseEntity<byte[]> monthlySummaryExcel(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam String templateCode) {
        byte[] body = excelService.buildMonthlyRanking(year, month, templateCode);
        ContentDisposition cd = ContentDisposition.attachment()
                .filename(String.format("thong-ke-xep-loai-dieu-duong-%d-%02d.xlsx", year, month),
                        java.nio.charset.StandardCharsets.UTF_8)
                .build();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .contentType(MediaType.parseMediaType(
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(body);
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
    public List<Map<String, Object>> history(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return nursingEvaluationService.listHistory(fromDate, toDate);
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
