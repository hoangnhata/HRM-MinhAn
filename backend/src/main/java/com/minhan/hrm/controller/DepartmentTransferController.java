package com.minhan.hrm.controller;

import com.minhan.hrm.dto.transfer.DepartmentTransferCreateRequest;
import com.minhan.hrm.dto.transfer.DepartmentTransferReviewRequest;
import com.minhan.hrm.service.DepartmentTransferService;
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
@RequestMapping("/j1-api/v1/department-transfers")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Department transfer", description = "Luân chuyển nhân viên — HCNS đề nghị, Giám đốc duyệt")
public class DepartmentTransferController {

    private final DepartmentTransferService transferService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "HCNS tạo đề nghị luân chuyển")
    public Map<String, Object> create(@Valid @RequestBody DepartmentTransferCreateRequest request) {
        return transferService.create(request);
    }

    @GetMapping("/pending")
    @PreAuthorize("hasAnyRole('ADMIN','DIRECTOR','HR')")
    @Operation(summary = "Danh sách chờ Giám đốc duyệt")
    public List<Map<String, Object>> pending() {
        return transferService.listPendingDirector();
    }

    @GetMapping("/history")
    @PreAuthorize("hasAnyRole('ADMIN','DIRECTOR','HR')")
    @Operation(summary = "Lịch sử đơn luân chuyển đã xử lý")
    public List<Map<String, Object>> history() {
        return transferService.listReviewHistory();
    }

    @GetMapping("/employee/{employeeId}")
    @PreAuthorize("hasAnyRole('ADMIN','HR','DIRECTOR')")
    public List<Map<String, Object>> byEmployee(@PathVariable Long employeeId) {
        return transferService.listByEmployee(employeeId);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','DIRECTOR','HR')")
    @Operation(summary = "Chi tiết một đề nghị luân chuyển")
    public Map<String, Object> get(@PathVariable Long id) {
        return transferService.getById(id);
    }

    @PostMapping("/{id}/director-review")
    @PreAuthorize("hasAnyRole('ADMIN','DIRECTOR')")
    @Operation(summary = "Giám đốc duyệt / từ chối")
    public Map<String, Object> directorReview(
            @PathVariable Long id,
            @Valid @RequestBody DepartmentTransferReviewRequest body) {
        return transferService.directorReview(id, body);
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Hủy đề nghị đang chờ")
    public Map<String, Object> cancel(@PathVariable Long id) {
        return transferService.cancel(id);
    }
}
