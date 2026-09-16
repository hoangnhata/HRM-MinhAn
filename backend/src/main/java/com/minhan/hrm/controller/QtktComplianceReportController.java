package com.minhan.hrm.controller;

import com.minhan.hrm.service.QtktComplianceReportExcelService;
import com.minhan.hrm.service.QtktComplianceReportPdfService;
import com.minhan.hrm.service.QtktComplianceReportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/qtkt-compliance-reports")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "QTKT compliance reports", description = "Báo cáo tuân thủ vệ sinh tay & quy trình kỹ thuật")
@PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING','HEAD_DEPARTMENT')")
public class QtktComplianceReportController {

    private final QtktComplianceReportService reportService;
    private final QtktComplianceReportExcelService excelService;
    private final QtktComplianceReportPdfService pdfService;

    @GetMapping("/departments")
    @Operation(summary = "Khoa trong phạm vi quyền (bộ lọc báo cáo)")
    public List<Map<String, Object>> departments(@RequestParam(required = false) String reportKind) {
        return reportService.listFilterDepartments(reportKind);
    }

    @GetMapping("/employees")
    @Operation(summary = "Nhân viên trong phạm vi quyền (lọc theo khoa nếu có)")
    public List<Map<String, Object>> employees(@RequestParam(required = false) Long departmentId) {
        return reportService.listFilterEmployees(departmentId);
    }

    @GetMapping("/hand-hygiene")
    @Operation(summary = "Báo cáo tỷ lệ tuân thủ vệ sinh tay")
    public Map<String, Object> handHygiene(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long employeeId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String resultFilter,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir,
            @RequestParam(required = false, defaultValue = "0") int page,
            @RequestParam(required = false, defaultValue = "20") int size) {
        DateRange range = resolveRange(from, to, yearMonth);
        return reportService.handHygieneReport(
                range.from(), range.to(), departmentId, employeeId, search, resultFilter, sortDir, page, size);
    }

    @GetMapping("/technical-procedures")
    @Operation(summary = "Báo cáo tỷ lệ tuân thủ quy trình kỹ thuật")
    public Map<String, Object> technicalProcedures(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long employeeId,
            @RequestParam(required = false) String procedureCode,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String resultFilter,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir,
            @RequestParam(required = false, defaultValue = "0") int page,
            @RequestParam(required = false, defaultValue = "20") int size) {
        DateRange range = resolveRange(from, to, yearMonth);
        return reportService.technicalReport(
                range.from(), range.to(), departmentId, employeeId, procedureCode,
                search, resultFilter, sortDir, page, size);
    }

    @GetMapping("/gdsk-counseling")
    @Operation(summary = "Báo cáo tỷ lệ tư vấn GDSK hiệu quả ở các khoa lâm sàng")
    public Map<String, Object> gdskCounseling(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long employeeId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String resultFilter,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir,
            @RequestParam(required = false, defaultValue = "0") int page,
            @RequestParam(required = false, defaultValue = "20") int size) {
        DateRange range = resolveRange(from, to, yearMonth);
        return reportService.gdskReport(
                range.from(), range.to(), departmentId, employeeId, search, resultFilter, sortDir, page, size);
    }

    @GetMapping("/hand-hygiene/excel")
    @Operation(summary = "Xuất Excel báo cáo vệ sinh tay")
    public ResponseEntity<byte[]> handHygieneExcel(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long employeeId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String resultFilter,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(from, to, yearMonth);
        byte[] bytes = excelService.exportHandHygiene(
                range.from(), range.to(), departmentId, employeeId, search, resultFilter, sortDir);
        return fileResponse(bytes, "bao-cao-ve-sinh-tay.xlsx",
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    }

    @GetMapping("/technical-procedures/excel")
    @Operation(summary = "Xuất Excel báo cáo QTKT")
    public ResponseEntity<byte[]> technicalExcel(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long employeeId,
            @RequestParam(required = false) String procedureCode,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String resultFilter,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(from, to, yearMonth);
        byte[] bytes = excelService.exportTechnical(
                range.from(), range.to(), departmentId, employeeId, procedureCode, search, resultFilter, sortDir);
        return fileResponse(bytes, "bao-cao-tuan-thu-qtk.xlsx",
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    }

    @GetMapping("/gdsk-counseling/excel")
    @Operation(summary = "Xuất Excel báo cáo tư vấn GDSK")
    public ResponseEntity<byte[]> gdskExcel(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long employeeId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String resultFilter,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(from, to, yearMonth);
        byte[] bytes = excelService.exportGdsk(
                range.from(), range.to(), departmentId, employeeId, search, resultFilter, sortDir);
        return fileResponse(bytes, "bao-cao-tu-van-gdsk.xlsx",
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    }

    @GetMapping("/hand-hygiene/pdf")
    @Operation(summary = "Xuất PDF báo cáo vệ sinh tay")
    public ResponseEntity<byte[]> handHygienePdf(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long employeeId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String resultFilter,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(from, to, yearMonth);
        byte[] bytes = pdfService.exportHandHygiene(
                range.from(), range.to(), departmentId, employeeId, search, resultFilter, sortDir);
        return fileResponse(bytes, "bao-cao-ve-sinh-tay.pdf", MediaType.APPLICATION_PDF_VALUE);
    }

    @GetMapping("/technical-procedures/pdf")
    @Operation(summary = "Xuất PDF báo cáo QTKT")
    public ResponseEntity<byte[]> technicalPdf(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long employeeId,
            @RequestParam(required = false) String procedureCode,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String resultFilter,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(from, to, yearMonth);
        byte[] bytes = pdfService.exportTechnical(
                range.from(), range.to(), departmentId, employeeId, procedureCode, search, resultFilter, sortDir);
        return fileResponse(bytes, "bao-cao-tuan-thu-qtk.pdf", MediaType.APPLICATION_PDF_VALUE);
    }

    @GetMapping("/gdsk-counseling/pdf")
    @Operation(summary = "Xuất PDF báo cáo tư vấn GDSK")
    public ResponseEntity<byte[]> gdskPdf(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) Long employeeId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String resultFilter,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(from, to, yearMonth);
        byte[] bytes = pdfService.exportGdsk(
                range.from(), range.to(), departmentId, employeeId, search, resultFilter, sortDir);
        return fileResponse(bytes, "bao-cao-tu-van-gdsk.pdf", MediaType.APPLICATION_PDF_VALUE);
    }

    private ResponseEntity<byte[]> fileResponse(byte[] bytes, String filename, String contentType) {
        ContentDisposition cd = ContentDisposition.attachment().filename(filename, StandardCharsets.UTF_8).build();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .contentType(MediaType.parseMediaType(contentType))
                .body(bytes);
    }

    private DateRange resolveRange(LocalDate from, LocalDate to, String yearMonth) {
        if (yearMonth != null && !yearMonth.isBlank()) {
            YearMonth ym = YearMonth.parse(yearMonth);
            LocalDate f = ym.atDay(1);
            LocalDate t = ym.equals(YearMonth.now()) ? LocalDate.now() : ym.atEndOfMonth();
            return new DateRange(f, t);
        }
        LocalDate f = from != null ? from : YearMonth.now().atDay(1);
        LocalDate t = to != null ? to : LocalDate.now();
        return new DateRange(f, t);
    }

    private record DateRange(LocalDate from, LocalDate to) {}
}
