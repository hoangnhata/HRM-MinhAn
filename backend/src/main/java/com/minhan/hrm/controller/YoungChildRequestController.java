package com.minhan.hrm.controller;

import com.minhan.hrm.dto.youngchild.YoungChildRequestCreateDto;
import com.minhan.hrm.dto.youngchild.YoungChildRequestReviewDto;
import com.minhan.hrm.service.YoungChildRequestService;
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
import java.time.LocalDate;

@RestController
@RequestMapping("/j1-api/v1/young-child-requests")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Young child requests", description = "Đề xuất chế độ nuôi con nhỏ — trưởng khoa → HCNS")
public class YoungChildRequestController {

    private final YoungChildRequestService requestService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Trưởng khoa đề xuất bật/tắt nuôi con nhỏ")
    public Map<String, Object> create(@Valid @RequestBody YoungChildRequestCreateDto body) {
        return requestService.create(body);
    }

    @GetMapping("/pending")
    @PreAuthorize("hasAnyRole('ADMIN','HR2')")
    public List<Map<String, Object>> pending() {
        return requestService.listPendingHr();
    }

    @GetMapping("/history")
    @PreAuthorize("hasAnyRole('ADMIN','HR2')")
    public List<Map<String, Object>> history() {
        return requestService.listHistory();
    }

    @GetMapping("/mine")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    public List<Map<String, Object>> mine() {
        return requestService.listMine();
    }

    @GetMapping("/employee/{employeeId}/pending")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','HEAD_DEPARTMENT')")
    public Map<String, Object> pendingForEmployeePeriod(
            @PathVariable Long employeeId,
            @RequestParam LocalDate fromDate,
            @RequestParam LocalDate toDate) {
        return requestService.getPendingForEmployeePeriod(employeeId, fromDate, toDate);
    }

    @GetMapping("/related-to-me")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Đề xuất nuôi con nhỏ liên quan đến tôi")
    public List<Map<String, Object>> relatedToMe() {
        return requestService.listRelatedToMe();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','HEAD_DEPARTMENT','EMPLOYEE')")
    public Map<String, Object> get(@PathVariable Long id) {
        return requestService.getById(id);
    }

    @PostMapping("/{id}/hr-review")
    @PreAuthorize("hasAnyRole('ADMIN','HR2')")
    public Map<String, Object> hrReview(
            @PathVariable Long id,
            @Valid @RequestBody YoungChildRequestReviewDto body) {
        return requestService.hrReview(id, body);
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    public Map<String, Object> cancel(@PathVariable Long id) {
        return requestService.cancel(id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "ADMIN thu hồi và xoá hẳn đơn nuôi con nhỏ")
    public void revoke(@PathVariable Long id) {
        requestService.revoke(id);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Chỉnh sửa đề xuất nuôi con nhỏ đang chờ duyệt (người lập hoặc ADMIN)")
    public Map<String, Object> update(
            @PathVariable Long id,
            @Valid @RequestBody YoungChildRequestCreateDto body) {
        return requestService.update(id, body);
    }
}
