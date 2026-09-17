package com.minhan.hrm.controller;

import com.minhan.hrm.dto.attendance.ManualLeaveAttachDto;
import com.minhan.hrm.service.ManualLeaveAdjustmentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/** Admin ghi nhận phép năm đã nghỉ ngoài hệ thống (gắn tay / import Excel). */
@RestController
@RequestMapping("/j1-api/v1/attendance/manual-leaves")
@RequiredArgsConstructor
@Tag(name = "Manual leave", description = "Gắn ngày phép đã nghỉ ngoài hệ thống (ADMIN)")
@SecurityRequirement(name = "bearerAuth")
@PreAuthorize("hasRole('ADMIN')")
public class ManualLeaveAdjustmentController {

    private final ManualLeaveAdjustmentService service;

    @GetMapping
    @Operation(summary = "Danh sách phép đã gắn trong năm")
    public List<Map<String, Object>> list(@RequestParam(required = false) Integer year) {
        return service.list(year != null ? year : LocalDate.now().getYear());
    }

    @PostMapping
    @Operation(summary = "Gắn tay phép đã nghỉ cho 1 nhân viên")
    public Map<String, Object> attach(@Valid @RequestBody ManualLeaveAttachDto dto) {
        return service.attachManual(dto);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Xoá phép đã gắn (hoàn lại hạn mức, gỡ đánh dấu bảng công)")
    public Map<String, Object> delete(@PathVariable Long id) {
        return service.delete(id);
    }

    @GetMapping("/template")
    @Operation(summary = "Tải file Excel mẫu (Họ tên, CCCD, Từ ngày, Đến ngày, Ghi chú)")
    public ResponseEntity<byte[]> template() {
        byte[] body = service.template();
        ContentDisposition cd = ContentDisposition.attachment()
                .filename("MAU-GAN-PHEP-NGOAI-HE-THONG.xlsx", StandardCharsets.UTF_8)
                .build();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .contentType(MediaType.parseMediaType(
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(body);
    }

    @PostMapping(value = "/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Import Excel — apply=false: kiểm tra trước; apply=true: ghi nhận các dòng hợp lệ")
    public Map<String, Object> importExcel(
            @RequestPart("file") MultipartFile file,
            @RequestParam(defaultValue = "false") boolean apply,
            @RequestParam(defaultValue = "true") boolean applyAttendance) {
        return service.importExcel(file, apply, applyAttendance);
    }
}
