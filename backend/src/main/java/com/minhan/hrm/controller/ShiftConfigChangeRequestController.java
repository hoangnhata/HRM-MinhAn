package com.minhan.hrm.controller;

import com.minhan.hrm.dto.shiftconfig.ShiftConfigChangeCreateDto;
import com.minhan.hrm.dto.shiftconfig.ShiftConfigChangeReviewDto;
import com.minhan.hrm.service.ShiftConfigChangeRequestService;
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
@RequestMapping("/j1-api/v1/shift-config-change-requests")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Shift config change", description = "Đề xuất chỉnh ca sáng/chiều — trưởng khoa → HCNS")
public class ShiftConfigChangeRequestController {

    private final ShiftConfigChangeRequestService requestService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Trưởng khoa đề xuất chỉnh cấu hình ca sáng/chiều")
    public Map<String, Object> create(@Valid @RequestBody ShiftConfigChangeCreateDto body) {
        return requestService.create(body);
    }

    @GetMapping("/pending")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','HEAD_DEPARTMENT')")
    public List<Map<String, Object>> pending() {
        return requestService.listPendingHr();
    }

    @GetMapping("/history")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','HEAD_DEPARTMENT')")
    public List<Map<String, Object>> history() {
        return requestService.listHistory();
    }

    @GetMapping("/mine")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    public List<Map<String, Object>> mine() {
        return requestService.listMine();
    }

    @GetMapping("/related-to-me")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Đề xuất chỉnh ca liên quan đến tôi")
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
            @Valid @RequestBody ShiftConfigChangeReviewDto body) {
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
    @Operation(summary = "ADMIN thu hồi và xoá hẳn đơn chỉnh ca")
    public void revoke(@PathVariable Long id) {
        requestService.revoke(id);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Chỉnh sửa đề xuất chỉnh ca đang chờ duyệt (người lập hoặc ADMIN)")
    public Map<String, Object> update(
            @PathVariable Long id,
            @Valid @RequestBody ShiftConfigChangeCreateDto body) {
        return requestService.update(id, body);
    }
}
