package com.minhan.hrm.controller;

import com.minhan.hrm.service.EmployeeDocumentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/documents")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Documents", description = "Upload & tải PDF hồ sơ")
public class EmployeeDocumentController {

    private final EmployeeDocumentService documentService;

    @DeleteMapping("/employees/{employeeId}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Xóa toàn bộ PDF đã đính kèm của nhân viên (ADMIN)")
    public ResponseEntity<Void> deleteAll(@PathVariable Long employeeId) {
        documentService.deleteAllForEmployee(employeeId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping(value = "/employees/{employeeId}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Upload PDF cho nhân viên (chỉ PDF)")
    public Map<String, Object> upload(
            @PathVariable Long employeeId,
            @RequestPart("file") MultipartFile file,
            @RequestParam(value = "docType", required = false) String docType) {
        return documentService.upload(employeeId, file, docType);
    }

    @GetMapping("/employees/{employeeId}")
    @Operation(summary = "Danh sách tài liệu (ADMIN hoặc chính nhân viên)")
    public List<Map<String, Object>> list(@PathVariable Long employeeId) {
        return documentService.list(employeeId);
    }

    @GetMapping("/{id}/file")
    @Operation(summary = "Tải file PDF")
    public ResponseEntity<Resource> download(@PathVariable("id") Long documentId) {
        var doc = documentService.requireDocument(documentId);
        Resource resource = documentService.loadFile(documentId);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + doc.getOriginalName() + "\"")
                .body(resource);
    }
}
