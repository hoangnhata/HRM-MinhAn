package com.minhan.hrm.controller;

import com.minhan.hrm.service.NursingActivityReportExcelService;
import com.minhan.hrm.service.NursingActivityReportPdfService;
import com.minhan.hrm.service.NursingActivityReportService;
import com.minhan.hrm.service.NursingActivityReportService.CompareMetric;
import com.minhan.hrm.service.NursingActivityReportService.DateRange;
import com.minhan.hrm.service.NursingActivityReportService.ReportKind;
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
import java.time.Year;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/nursing-activity-reports")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Nursing activity reports", description = "Báo cáo hoạt động điều dưỡng")
@PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING','HEAD_DEPARTMENT')")
public class NursingActivityReportController {

    private final NursingActivityReportService reportService;
    private final NursingActivityReportExcelService excelService;
    private final NursingActivityReportPdfService pdfService;

    @GetMapping("/departments")
    @Operation(summary = "Khoa trong phạm vi quyền")
    public List<Map<String, Object>> departments() {
        return reportService.listFilterDepartments();
    }

    @GetMapping("/overview")
    public Map<String, Object> overview(
            @RequestParam(required = false) String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer quarter,
            @RequestParam(required = false) Integer half,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false, defaultValue = "FALL_RATE") String compareMetric) {
        DateRange range = resolveRange(periodType, from, to, yearMonth, year, quarter, half);
        return reportService.overview(range.from(), range.to(), departmentId, parseCompareMetric(compareMetric));
    }

    @GetMapping("/falls")
    public Map<String, Object> falls(
            @RequestParam(required = false) String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer quarter,
            @RequestParam(required = false) Integer half,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false, defaultValue = "RATE") String sortBy,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(periodType, from, to, yearMonth, year, quarter, half);
        return reportService.fallsReport(range.from(), range.to(), departmentId, sortBy, sortDir);
    }

    @GetMapping("/pressure-ulcers")
    public Map<String, Object> pressureUlcers(
            @RequestParam(required = false) String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer quarter,
            @RequestParam(required = false) Integer half,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false, defaultValue = "RATE") String sortBy,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(periodType, from, to, yearMonth, year, quarter, half);
        return reportService.pressureUlcerReport(range.from(), range.to(), departmentId, sortBy, sortDir);
    }

    @GetMapping("/nurse-bed")
    public Map<String, Object> nurseBed(
            @RequestParam(required = false) String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer quarter,
            @RequestParam(required = false) Integer half,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(periodType, from, to, yearMonth, year, quarter, half);
        return reportService.nurseBedReport(range.from(), range.to(), departmentId, null, sortDir);
    }

    @GetMapping("/id-mixups")
    public Map<String, Object> idMixups(
            @RequestParam(required = false) String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer quarter,
            @RequestParam(required = false) Integer half,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(periodType, from, to, yearMonth, year, quarter, half);
        return reportService.idMixupReport(range.from(), range.to(), departmentId, null, sortDir);
    }

    @GetMapping("/medication-errors")
    public Map<String, Object> medicationErrors(
            @RequestParam(required = false) String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer quarter,
            @RequestParam(required = false) Integer half,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false, defaultValue = "DESC") String sortDir) {
        DateRange range = resolveRange(periodType, from, to, yearMonth, year, quarter, half);
        return reportService.medicationErrorReport(range.from(), range.to(), departmentId, null, sortDir);
    }

    @GetMapping("/departments/{departmentId}/detail")
    public Map<String, Object> departmentDetail(
            @PathVariable Long departmentId,
            @RequestParam(required = false) String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer quarter,
            @RequestParam(required = false) Integer half) {
        DateRange range = resolveRange(periodType, from, to, yearMonth, year, quarter, half);
        return reportService.departmentDetail(departmentId, range.from(), range.to());
    }

    @GetMapping("/{kind}/excel")
    public ResponseEntity<byte[]> exportExcel(
            @PathVariable String kind,
            @RequestParam(required = false) String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer quarter,
            @RequestParam(required = false) Integer half,
            @RequestParam(required = false) Long departmentId) {
        DateRange range = resolveRange(periodType, from, to, yearMonth, year, quarter, half);
        ReportKind rk = parseKind(kind);
        byte[] bytes = excelService.export(rk, range.from(), range.to(), departmentId);
        return fileResponse(bytes, fileName(rk, "xlsx"),
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    }

    @GetMapping("/{kind}/pdf")
    public ResponseEntity<byte[]> exportPdf(
            @PathVariable String kind,
            @RequestParam(required = false) String periodType,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String yearMonth,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer quarter,
            @RequestParam(required = false) Integer half,
            @RequestParam(required = false) Long departmentId) {
        DateRange range = resolveRange(periodType, from, to, yearMonth, year, quarter, half);
        ReportKind rk = parseKind(kind);
        byte[] bytes = pdfService.export(rk, range.from(), range.to(), departmentId);
        return fileResponse(bytes, fileName(rk, "pdf"), MediaType.APPLICATION_PDF_VALUE);
    }

    private ResponseEntity<byte[]> fileResponse(byte[] bytes, String filename, String contentType) {
        ContentDisposition cd = ContentDisposition.attachment().filename(filename, StandardCharsets.UTF_8).build();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .contentType(MediaType.parseMediaType(contentType))
                .body(bytes);
    }

    private ReportKind parseKind(String kind) {
        return switch (kind.toLowerCase()) {
            case "overview" -> ReportKind.OVERVIEW;
            case "falls" -> ReportKind.FALLS;
            case "pressure-ulcers" -> ReportKind.PRESSURE_ULCER;
            case "nurse-bed" -> ReportKind.NURSE_BED;
            case "id-mixups" -> ReportKind.ID_MIXUP;
            case "medication-errors" -> ReportKind.MEDICATION_ERROR;
            default -> throw new IllegalArgumentException("Loại báo cáo không hợp lệ: " + kind);
        };
    }

    private CompareMetric parseCompareMetric(String metric) {
        try {
            return CompareMetric.valueOf(metric.toUpperCase());
        } catch (Exception ex) {
            return CompareMetric.FALL_RATE;
        }
    }

    private String fileName(ReportKind kind, String ext) {
        String slug = switch (kind) {
            case OVERVIEW -> "tong-quan-hoat-dong-dieu-duong";
            case FALLS -> "ty-le-te-nga";
            case PRESSURE_ULCER -> "ty-le-loet-ti-de";
            case NURSE_BED -> "ty-le-dieu-duong-nguoi-benh";
            case ID_MIXUP -> "nham-lan-xac-dinh-nb";
            case MEDICATION_ERROR -> "sai-sot-dung-thuoc";
        };
        return "bao-cao-" + slug + "." + ext;
    }

    private DateRange resolveRange(
            String periodType,
            LocalDate from,
            LocalDate to,
            String yearMonth,
            Integer year,
            Integer quarter,
            Integer half) {
        String pt = periodType != null ? periodType.toUpperCase() : "MONTH";
        LocalDate today = LocalDate.now();
        return switch (pt) {
            case "DAY" -> {
                LocalDate d = from != null ? from : today;
                yield new DateRange(d, d);
            }
            case "QUARTER" -> {
                int y = year != null ? year : today.getYear();
                int q = quarter != null ? quarter : ((today.getMonthValue() - 1) / 3 + 1);
                int startMonth = (q - 1) * 3 + 1;
                YearMonth ym = YearMonth.of(y, startMonth);
                LocalDate f = ym.atDay(1);
                LocalDate t = ym.plusMonths(2).atEndOfMonth();
                if (Year.of(y).equals(Year.from(today)) && t.isAfter(today)) t = today;
                yield new DateRange(f, t);
            }
            case "HALF_YEAR" -> {
                int y = year != null ? year : today.getYear();
                int h = half != null ? half : (today.getMonthValue() <= 6 ? 1 : 2);
                LocalDate f = h == 1 ? LocalDate.of(y, 1, 1) : LocalDate.of(y, 7, 1);
                LocalDate t = h == 1 ? LocalDate.of(y, 6, 30) : LocalDate.of(y, 12, 31);
                if (t.isAfter(today)) t = today;
                yield new DateRange(f, t);
            }
            case "YEAR" -> {
                int y = year != null ? year : today.getYear();
                LocalDate f = LocalDate.of(y, 1, 1);
                LocalDate t = LocalDate.of(y, 12, 31);
                if (t.isAfter(today)) t = today;
                yield new DateRange(f, t);
            }
            case "CUSTOM" -> {
                LocalDate f = from != null ? from : YearMonth.now().atDay(1);
                LocalDate t = to != null ? to : today;
                yield new DateRange(f, t);
            }
            default -> {
                if (yearMonth != null && !yearMonth.isBlank()) {
                    YearMonth ym = YearMonth.parse(yearMonth);
                    LocalDate f = ym.atDay(1);
                    LocalDate t = ym.equals(YearMonth.from(today)) ? today : ym.atEndOfMonth();
                    yield new DateRange(f, t);
                }
                LocalDate f = from != null ? from : YearMonth.now().atDay(1);
                LocalDate t = to != null ? to : today;
                yield new DateRange(f, t);
            }
        };
    }
}
