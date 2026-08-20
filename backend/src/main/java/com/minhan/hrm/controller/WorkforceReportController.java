package com.minhan.hrm.controller;

import com.minhan.hrm.service.WorkforceReportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/workforce-reports")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@PreAuthorize("hasAnyRole('ADMIN','HR','HR2','DIRECTOR','REPORT_VIEWER')")
public class WorkforceReportController {

    private final WorkforceReportService reportService;

    @GetMapping("/hospital")
    @Operation(summary = "Báo cáo nhân lực toàn viện")
    public Map<String, Object> hospital() { return reportService.hospitalReport(); }

    @GetMapping("/daily")
    @Operation(summary = "Báo cáo nhân lực thực tế đi làm theo ngày")
    public Map<String, Object> daily(@RequestParam LocalDate date) { return reportService.dailyReport(date); }

    @GetMapping("/hospital/excel")
    public ResponseEntity<byte[]> hospitalExcel() {
        return excel(reportService.exportHospitalExcel(), "bao-cao-nhan-luc-toan-vien.xlsx");
    }

    @GetMapping("/daily/excel")
    public ResponseEntity<byte[]> dailyExcel(@RequestParam LocalDate date) {
        return excel(reportService.exportDailyExcel(date), "bao-cao-nhan-luc-di-lam-" + date + ".xlsx");
    }

    private static ResponseEntity<byte[]> excel(byte[] body, String filename) {
        ContentDisposition cd = ContentDisposition.attachment().filename(filename, StandardCharsets.UTF_8).build();
        return ResponseEntity.ok().header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(body);
    }
}
