package com.minhan.hrm.controller;

import com.minhan.hrm.dto.qtkt.QtktEvaluationUpsertRequest;
import com.minhan.hrm.service.QtktEvaluationService;
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
@RequestMapping("/j1-api/v1/qtkt-evaluations")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "QTKT evaluations", description = "Đánh giá quy trình kỹ thuật điều dưỡng")
@PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING','HEAD_DEPARTMENT')")
public class QtktEvaluationController {

    private final QtktEvaluationService service;

    @GetMapping("/template")
    @Operation(summary = "Template các quy trình kỹ thuật + bước điểm")
    public Map<String, Object> template() {
        return service.getTemplate();
    }

    @GetMapping("/employees")
    @Operation(summary = "NV khối ĐD trong phạm vi quyền để đánh giá")
    public List<Map<String, Object>> employees() {
        return service.listEligibleEmployees();
    }

    @GetMapping("/departments")
    @Operation(summary = "Khoa trong phạm vi quyền")
    public List<Map<String, Object>> departments() {
        return service.listDepartments();
    }

    @GetMapping
    @Operation(summary = "Danh sách phiếu đánh giá")
    public List<Map<String, Object>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) String procedureCode,
            @RequestParam(required = false) String status) {
        return service.list(from, to, departmentId, procedureCode, status);
    }

    @GetMapping("/summary")
    @Operation(summary = "Tổng hợp theo tháng (Trưởng phòng ĐD / ADMIN / Trưởng khoa)")
    public Map<String, Object> summary(@RequestParam(required = false) String yearMonth) {
        return service.summary(yearMonth);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Chi tiết phiếu")
    public Map<String, Object> get(@PathVariable Long id) {
        return service.getById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Tạo phiếu đánh giá (nháp hoặc gửi)")
    public Map<String, Object> create(@Valid @RequestBody QtktEvaluationUpsertRequest request) {
        return service.upsert(null, request);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Cập nhật phiếu")
    public Map<String, Object> update(
            @PathVariable Long id, @Valid @RequestBody QtktEvaluationUpsertRequest request) {
        return service.upsert(id, request);
    }

    @PostMapping("/{id}/submit")
    @Operation(summary = "Gửi phiếu cho Trưởng phòng Điều dưỡng")
    public Map<String, Object> submit(@PathVariable Long id) {
        return service.submit(id);
    }

    @PostMapping("/{id}/recall")
    @Operation(summary = "Thu hồi phiếu đã gửi về nháp (Trưởng khoa trong 1 ngày; Trưởng phòng ĐD / ADMIN mọi lúc)")
    public Map<String, Object> recall(@PathVariable Long id) {
        return service.recall(id);
    }

    @PostMapping("/{id}/cancel")
    @Operation(summary = "Thu hồi phiếu (tương thích — giống recall)")
    public Map<String, Object> cancel(@PathVariable Long id) {
        return service.recall(id);
    }
}
