package com.minhan.hrm.controller;

import com.minhan.hrm.service.WorkforceExcelImportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/import")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Import", description = "Nhập Excel nhân lực BVMA")
public class WorkforceImportController {

    private final WorkforceExcelImportService workforceExcelImportService;

    @PostMapping(value = "/workforce", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Import file TỔNG HỢP THÔNG TIN NHÂN LỰC (.xlsx) — tạo/cập nhật nhân viên + đủ cột mở rộng")
    public Map<String, Object> importWorkforce(@RequestPart("file") MultipartFile file) {
        return workforceExcelImportService.importWorkforceExcel(file);
    }
}
