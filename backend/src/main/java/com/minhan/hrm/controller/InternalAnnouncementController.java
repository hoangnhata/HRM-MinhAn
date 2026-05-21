package com.minhan.hrm.controller;

import com.minhan.hrm.dto.announcement.AnnouncementRequest;
import com.minhan.hrm.service.InternalAnnouncementService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/announcements")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Announcements", description = "Văn bản nội viện")
public class InternalAnnouncementController {

    private final InternalAnnouncementService announcementService;

    @GetMapping
    @Operation(summary = "Danh sách thông báo nội bộ đang hiệu lực (lọc theo mục/tab)")
    public List<Map<String, Object>> list(@RequestParam(required = false) String category) {
        return announcementService.listActive(category);
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Đăng thông báo nội bộ (JSON, không file đính kèm)")
    public Map<String, Object> createJson(@Valid @RequestBody AnnouncementRequest request) {
        return announcementService.create(request, List.of());
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Đăng thông báo kèm file đính kèm — part data JSON, part files")
    public Map<String, Object> createMultipart(
            @Valid @RequestPart("data") AnnouncementRequest request,
            @RequestPart(value = "files", required = false) List<MultipartFile> files) {
        List<MultipartFile> list = files != null ? files : List.of();
        return announcementService.create(request, list);
    }

    @GetMapping("/attachments/{attachmentId}/file")
    @Operation(summary = "Tải file đính kèm thông báo")
    public ResponseEntity<Resource> downloadAttachment(@PathVariable Long attachmentId) {
        return announcementService.serveAttachment(attachmentId);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('ADMIN')")
    public void delete(@PathVariable Long id) {
        announcementService.delete(id);
    }
}
