package com.minhan.hrm.controller;

import com.minhan.hrm.service.ProfessionalQualificationReportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/professional-qualification-reports")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@PreAuthorize("hasAnyRole('ADMIN','HR','HR2','DIRECTOR','PROFESSIONAL_QUALIFICATION_VIEWER')")
public class ProfessionalQualificationReportController {

    private final ProfessionalQualificationReportService reportService;

    @GetMapping
    @Operation(summary = "Báo cáo trình độ chuyên môn theo đối tượng (Bác sĩ, ĐD, HS, KTV, Y sĩ, Dược sĩ)")
    public Map<String, Object> overview() {
        return reportService.overview();
    }

    @GetMapping("/excel")
    @Operation(summary = "Xuất Excel báo cáo trình độ chuyên môn")
    public ResponseEntity<byte[]> excel() {
        byte[] body = reportService.exportExcel();
        ContentDisposition cd = ContentDisposition.attachment()
                .filename("bao-cao-trinh-do-chuyen-mon.xlsx", StandardCharsets.UTF_8)
                .build();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .contentType(MediaType.parseMediaType(
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(body);
    }
}
