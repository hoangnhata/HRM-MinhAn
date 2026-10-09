package com.minhan.hrm.controller;

import com.minhan.hrm.dto.seminar.SeminarProposalCreateRequest;
import com.minhan.hrm.dto.seminar.SeminarProposalReviewRequest;
import com.minhan.hrm.service.SeminarProposalService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/seminar-proposals")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Seminar proposals", description = "Phiếu đề xuất cử CBNV tham gia hội thảo")
public class SeminarProposalController {

    private final SeminarProposalService proposalService;

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Trưởng khoa / Điều dưỡng trưởng lập phiếu đề xuất hội thảo")
    public Map<String, Object> create(@Valid @RequestBody SeminarProposalCreateRequest request) {
        return proposalService.create(request);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Lập phiếu hội thảo kèm công văn đính kèm")
    public Map<String, Object> createWithFiles(
            @Valid @RequestPart("request") SeminarProposalCreateRequest request,
            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        return proposalService.create(request, files);
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
    public List<Map<String, Object>> history(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return proposalService.listReviewHistory(fromDate, toDate);
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
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Bước HCNS đã bỏ — endpoint giữ để tương thích, chỉ ADMIN")
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

    @PutMapping(value = "/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Chỉnh sửa phiếu hội thảo đang chờ duyệt (người lập hoặc ADMIN)")
    public Map<String, Object> update(
            @PathVariable Long id,
            @Valid @RequestBody SeminarProposalCreateRequest request) {
        return proposalService.update(id, request);
    }

    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Chỉnh sửa phiếu hội thảo và bổ sung công văn")
    public Map<String, Object> updateWithFiles(
            @PathVariable Long id,
            @Valid @RequestPart("request") SeminarProposalCreateRequest request,
            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        return proposalService.update(id, request, files);
    }

    @GetMapping("/{id}/attachments/{attachmentId}")
    @PreAuthorize("hasAnyRole('ADMIN','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING','EMPLOYEE')")
    public ResponseEntity<Resource> downloadAttachment(
            @PathVariable Long id,
            @PathVariable Long attachmentId) throws java.io.IOException {
        var attachment = proposalService.readAttachment(id, attachmentId);
        Path path = proposalService.resolveAttachment(attachment.getStoredPath());
        if (!Files.exists(path)) {
            return ResponseEntity.notFound().build();
        }
        String type = attachment.getContentType() != null ? attachment.getContentType() : MediaType.APPLICATION_OCTET_STREAM_VALUE;
        boolean inline = type.startsWith("image/") || "application/pdf".equals(type);
        ContentDisposition disposition = (inline ? ContentDisposition.inline() : ContentDisposition.attachment())
                .filename(attachment.getOriginalName(), StandardCharsets.UTF_8)
                .build();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .contentType(MediaType.parseMediaType(type))
                .body(new FileSystemResource(path));
    }

    @DeleteMapping("/{id}/attachments/{attachmentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT','HEAD_NURSING')")
    public void deleteAttachment(@PathVariable Long id, @PathVariable Long attachmentId) {
        proposalService.deleteAttachment(id, attachmentId);
    }
}
