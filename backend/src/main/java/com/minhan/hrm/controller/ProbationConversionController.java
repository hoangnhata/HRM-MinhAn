package com.minhan.hrm.controller;

import com.minhan.hrm.dto.probation.ProbationConversionCreateRequest;
import com.minhan.hrm.dto.probation.ProbationConversionReviewRequest;
import com.minhan.hrm.service.ProbationConversionService;
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
@RequestMapping("/j1-api/v1/probation-conversions")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Probation conversion", description = "Đơn chuyển thử việc/thực tập lên chính thức")
public class ProbationConversionController {

    private final ProbationConversionService conversionService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Trưởng khoa / Điều dưỡng trưởng lập đơn chuyển chính thức")
    public Map<String, Object> create(@Valid @RequestBody ProbationConversionCreateRequest request) {
        return conversionService.create(request);
    }

    @GetMapping("/pending-hr")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR')")
    @Operation(summary = "Đơn chờ HCNS duyệt")
    public List<Map<String, Object>> pendingHr() {
        return conversionService.listPendingHr();
    }

    @GetMapping("/pending-nursing-head")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Đơn chờ Trưởng phòng Điều dưỡng duyệt")
    public List<Map<String, Object>> pendingNursingHead() {
        return conversionService.listPendingNursingHead();
    }

    @GetMapping("/pending-director")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR')")
    @Operation(summary = "Đơn chờ Giám đốc duyệt")
    public List<Map<String, Object>> pendingDirector() {
        return conversionService.listPendingDirector();
    }

    @GetMapping("/history")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_NURSING')")
    @Operation(summary = "Lịch sử đơn đã xử lý")
    public List<Map<String, Object>> history() {
        return conversionService.listReviewHistory();
    }

    @GetMapping("/mine")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Đơn do tôi lập")
    public List<Map<String, Object>> mine() {
        return conversionService.listMine();
    }

    @GetMapping("/related-to-me")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Đơn chuyển chính thức liên quan đến tôi")
    public List<Map<String, Object>> relatedToMe() {
        return conversionService.listRelatedToMe();
    }

    @GetMapping("/employee/{employeeId}")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING','EMPLOYEE')")
    public List<Map<String, Object>> byEmployee(@PathVariable Long employeeId) {
        return conversionService.listByEmployee(employeeId);
    }

    @GetMapping("/form-type/{employeeId}")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT')")
    @Operation(summary = "Xác định mẫu đơn (bác sĩ / điều dưỡng / nhân viên) theo hồ sơ")
    public Map<String, Object> formType(@PathVariable Long employeeId) {
        return conversionService.resolveFormType(employeeId);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING','EMPLOYEE')")
    @Operation(summary = "Chi tiết đơn")
    public Map<String, Object> get(@PathVariable Long id) {
        return conversionService.getById(id);
    }

    @PostMapping("/{id}/nursing-head-review")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Operation(summary = "Trưởng phòng Điều dưỡng duyệt / từ chối")
    public Map<String, Object> nursingHeadReview(
            @PathVariable Long id,
            @Valid @RequestBody ProbationConversionReviewRequest body) {
        return conversionService.nursingHeadReview(id, body);
    }

    @PostMapping("/{id}/hr-review")
    @PreAuthorize("hasAnyRole('ADMIN','HR2')")
    @Operation(summary = "HCNS duyệt / từ chối")
    public Map<String, Object> hrReview(
            @PathVariable Long id,
            @Valid @RequestBody ProbationConversionReviewRequest body) {
        return conversionService.hrReview(id, body);
    }

    @PostMapping("/{id}/director-review")
    @PreAuthorize("hasAnyRole('ADMIN','DIRECTOR')")
    @Operation(summary = "Giám đốc duyệt / từ chối")
    public Map<String, Object> directorReview(
            @PathVariable Long id,
            @Valid @RequestBody ProbationConversionReviewRequest body) {
        return conversionService.directorReview(id, body);
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Hủy đơn đang chờ")
    public Map<String, Object> cancel(@PathVariable Long id) {
        return conversionService.cancel(id);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Operation(summary = "Chỉnh sửa đơn chuyển chính thức đang chờ duyệt (người lập hoặc ADMIN)")
    public Map<String, Object> update(
            @PathVariable Long id,
            @Valid @RequestBody ProbationConversionCreateRequest request) {
        return conversionService.update(id, request);
    }
}
