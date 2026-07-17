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

@RestController
@RequestMapping("/j1-api/v1/young-child-requests")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Young child requests", description = "Đề xuất chế độ nuôi con nhỏ — trưởng khoa → HCNS")
public class YoungChildRequestController {

    private final YoungChildRequestService requestService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Trưởng khoa đề xuất bật/tắt nuôi con nhỏ")
    public Map<String, Object> create(@Valid @RequestBody YoungChildRequestCreateDto body) {
        return requestService.create(body);
    }

    @GetMapping("/pending")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    public List<Map<String, Object>> pending() {
        return requestService.listPendingHr();
    }

    @GetMapping("/history")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    public List<Map<String, Object>> history() {
        return requestService.listHistory();
    }

    @GetMapping("/mine")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    public List<Map<String, Object>> mine() {
        return requestService.listMine();
    }

    @GetMapping("/employee/{employeeId}/pending")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    public Map<String, Object> pendingForEmployeeMonth(
            @PathVariable Long employeeId,
            @RequestParam int year,
            @RequestParam int month) {
        return requestService.getPendingForEmployeeMonth(employeeId, year, month);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    public Map<String, Object> get(@PathVariable Long id) {
        return requestService.getById(id);
    }

    @PostMapping("/{id}/hr-review")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    public Map<String, Object> hrReview(
            @PathVariable Long id,
            @Valid @RequestBody YoungChildRequestReviewDto body) {
        return requestService.hrReview(id, body);
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    public Map<String, Object> cancel(@PathVariable Long id) {
        return requestService.cancel(id);
    }
}
