package com.minhan.hrm.controller;

import com.minhan.hrm.dto.seminar.SeminarProposalCreateRequest;
import com.minhan.hrm.dto.seminar.SeminarProposalReviewRequest;
import com.minhan.hrm.service.SeminarProposalService;
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
@RequestMapping("/j1-api/v1/seminar-proposals")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Seminar proposals", description = "Phiếu đề xuất cử CBNV tham gia hội thảo")
public class SeminarProposalController {

    private final SeminarProposalService proposalService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Trưởng khoa / Điều dưỡng trưởng lập phiếu đề xuất hội thảo")
    public Map<String, Object> create(@Valid @RequestBody SeminarProposalCreateRequest request) {
        return proposalService.create(request);
    }

    @GetMapping("/pending-hr")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING')")
    public List<Map<String, Object>> pendingHr() {
        return proposalService.listPendingHr();
    }

    @GetMapping("/pending-director")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING')")
    public List<Map<String, Object>> pendingDirector() {
        return proposalService.listPendingDirector();
    }

    @GetMapping("/history")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING')")
    public List<Map<String, Object>> history() {
        return proposalService.listReviewHistory();
    }

    @GetMapping("/mine")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    public List<Map<String, Object>> mine() {
        return proposalService.listMine();
    }

    @GetMapping("/related-to-me")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Phiếu hội thảo liên quan đến tôi (là CBNV được cử đi)")
    public List<Map<String, Object>> relatedToMe() {
        return proposalService.listRelatedToMe();
    }

    @GetMapping("/employee/{employeeId}")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING','EMPLOYEE')")
    public List<Map<String, Object>> byEmployee(@PathVariable Long employeeId) {
        return proposalService.listByEmployee(employeeId);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING','EMPLOYEE')")
    public Map<String, Object> get(@PathVariable Long id) {
        return proposalService.getById(id);
    }

    @PostMapping("/{id}/hr-review")
    @PreAuthorize("hasAnyRole('ADMIN','HR2')")
    @Operation(summary = "HCNS chọn có công / không công rồi chuyển Giám đốc, hoặc từ chối")
    public Map<String, Object> hrReview(
            @PathVariable Long id,
            @Valid @RequestBody SeminarProposalReviewRequest body) {
        return proposalService.hrReview(id, body);
    }

    @PostMapping("/{id}/director-review")
    @PreAuthorize("hasAnyRole('ADMIN','DIRECTOR')")
    @Operation(summary = "Giám đốc duyệt cuối — áp dụng công hội thảo theo lựa chọn HCNS")
    public Map<String, Object> directorReview(
            @PathVariable Long id,
            @Valid @RequestBody SeminarProposalReviewRequest body) {
        return proposalService.directorReview(id, body);
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    public Map<String, Object> cancel(@PathVariable Long id) {
        return proposalService.cancel(id);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Chỉnh sửa phiếu hội thảo đang chờ duyệt (người lập hoặc ADMIN)")
    public Map<String, Object> update(
            @PathVariable Long id,
            @Valid @RequestBody SeminarProposalCreateRequest request) {
        return proposalService.update(id, request);
    }
}
