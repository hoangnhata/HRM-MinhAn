package com.minhan.hrm.controller;

import com.minhan.hrm.dto.mainduty.MainDutyAuthorizationCreateRequest;
import com.minhan.hrm.dto.mainduty.MainDutyAuthorizationReviewRequest;
import com.minhan.hrm.service.MainDutyAuthorizationService;
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
@RequestMapping("/j1-api/v1/main-duty-authorizations")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Main duty authorization", description = "Đơn được trực chính")
public class MainDutyAuthorizationController {

    private final MainDutyAuthorizationService authorizationService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Trưởng khoa / Điều dưỡng trưởng lập đơn trực chính cho CBNV")
    public Map<String, Object> create(@Valid @RequestBody MainDutyAuthorizationCreateRequest request) {
        return authorizationService.create(request);
    }

    @GetMapping("/pending-head")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT')")
    public List<Map<String, Object>> pendingHead() {
        return authorizationService.listPendingHead();
    }

    @GetMapping("/pending-nursing-head")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Đơn chờ Trưởng phòng Điều dưỡng duyệt")
    public List<Map<String, Object>> pendingNursingHead() {
        return authorizationService.listPendingNursingHead();
    }

    @GetMapping("/pending-hr")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT')")
    public List<Map<String, Object>> pendingHr() {
        return authorizationService.listPendingHr();
    }

    @GetMapping("/pending-director")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT')")
    public List<Map<String, Object>> pendingDirector() {
        return authorizationService.listPendingDirector();
    }

    @GetMapping("/history")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING')")
    public List<Map<String, Object>> history() {
        return authorizationService.listHistory();
    }

    @GetMapping("/mine")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    public List<Map<String, Object>> mine() {
        return authorizationService.listMine();
    }

    @GetMapping("/related-to-me")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Đơn trực chính liên quan đến tôi (là CBNV được đề xuất)")
    public List<Map<String, Object>> relatedToMe() {
        return authorizationService.listRelatedToMe();
    }

    @GetMapping("/employee/{employeeId}")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING','EMPLOYEE')")
    public List<Map<String, Object>> byEmployee(@PathVariable Long employeeId) {
        return authorizationService.listByEmployee(employeeId);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING','EMPLOYEE')")
    public Map<String, Object> get(@PathVariable Long id) {
        return authorizationService.getById(id);
    }

    @PostMapping("/{id}/head-review")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Trưởng khoa duyệt bước 1")
    public Map<String, Object> headReview(
            @PathVariable Long id,
            @Valid @RequestBody MainDutyAuthorizationReviewRequest body) {
        return authorizationService.headReview(id, body);
    }

    @PostMapping("/{id}/nursing-head-review")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Trưởng phòng Điều dưỡng duyệt bước khối ĐD")
    public Map<String, Object> nursingHeadReview(
            @PathVariable Long id,
            @Valid @RequestBody MainDutyAuthorizationReviewRequest body) {
        return authorizationService.nursingHeadReview(id, body);
    }

    @PostMapping("/{id}/hr-review")
    @PreAuthorize("hasAnyRole('ADMIN','HR2')")
    @Operation(summary = "HCNS duyệt bước 2")
    public Map<String, Object> hrReview(
            @PathVariable Long id,
            @Valid @RequestBody MainDutyAuthorizationReviewRequest body) {
        return authorizationService.hrReview(id, body);
    }

    @PostMapping("/{id}/director-review")
    @PreAuthorize("hasAnyRole('ADMIN','DIRECTOR')")
    @Operation(summary = "Giám đốc duyệt cuối — cấp quyền trực chính")
    public Map<String, Object> directorReview(
            @PathVariable Long id,
            @Valid @RequestBody MainDutyAuthorizationReviewRequest body) {
        return authorizationService.directorReview(id, body);
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    public Map<String, Object> cancel(@PathVariable Long id) {
        return authorizationService.cancel(id);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Chỉnh sửa đơn trực chính đang chờ duyệt (người lập hoặc ADMIN)")
    public Map<String, Object> update(
            @PathVariable Long id,
            @Valid @RequestBody MainDutyAuthorizationCreateRequest request) {
        return authorizationService.update(id, request);
    }
}
