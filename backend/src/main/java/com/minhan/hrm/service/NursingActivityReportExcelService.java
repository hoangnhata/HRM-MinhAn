package com.minhan.hrm.service;

import com.minhan.hrm.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFColor;
import org.apache.poi.xssf.usermodel.XSSFFont;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class NursingActivityReportExcelService {

    private static final String FONT = "Times New Roman";
    private static final String BRAND = "0F766E";
    private static final String BRAND_DARK = "0F4C5C";
    private static final String BRAND_LIGHT = "E6F7F5";
    private static final String INK = "0F172A";
    private static final String MUTED = "64748B";
    private static final String BORDER = "CBD5E1";
    private static final String ZEBRA = "F8FAFC";
    private static final String KPI_VALUE_BG = "F0FDFA";
    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final NursingActivityReportService reportService;

    public byte[] export(NursingActivityReportService.ReportKind kind, LocalDate from, LocalDate to, Long departmentId) {
        Map<String, Object> report = loadReport(kind, from, to, departmentId);
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Styles s = new Styles(wb);
            writeSummarySheet(wb, s, report, kind);
            writeDeptSheet(wb, s, report, kind);
            applyPrintSetup(wb);
            wb.write(out);
            return out.toByteArray();
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file Excel: " + ex.getMessage());
        }
    }

    private Map<String, Object> loadReport(
            NursingActivityReportService.ReportKind kind, LocalDate from, LocalDate to, Long departmentId) {
        return switch (kind) {
            case OVERVIEW -> reportService.overview(from, to, departmentId, null);
            case FALLS -> reportService.fallsReport(from, to, departmentId, "RATE", "DESC");
            case PRESSURE_ULCER -> reportService.pressureUlcerReport(from, to, departmentId, "RATE", "DESC");
            case NURSE_BED -> reportService.nurseBedReport(from, to, departmentId, null, "DESC");
            case ID_MIXUP -> reportService.idMixupReport(from, to, departmentId, null, "DESC");
            case MEDICATION_ERROR -> reportService.medicationErrorReport(from, to, departmentId, null, "DESC");
        };
    }

    private void applyPrintSetup(Workbook wb) {
        for (int i = 0; i < wb.getNumberOfSheets(); i++) {
            Sheet sheet = wb.getSheetAt(i);
            PrintSetup ps = sheet.getPrintSetup();
            ps.setLandscape(true);
            ps.setPaperSize(PrintSetup.A4_PAPERSIZE);
            ps.setFitWidth((short) 1);
            ps.setFitHeight((short) 0);
            sheet.setFitToPage(true);
            sheet.setAutobreaks(true);
            sheet.setMargin(Sheet.LeftMargin, 0.45);
            sheet.setMargin(Sheet.RightMargin, 0.45);
            sheet.setMargin(Sheet.TopMargin, 0.55);
            sheet.setMargin(Sheet.BottomMargin, 0.55);
            Footer footer = sheet.getFooter();
            footer.setLeft("Bệnh viện Minh An — Báo cáo hoạt động điều dưỡng");
            footer.setCenter("&A");
            footer.setRight("Trang &P / &N");
        }
    }

    private void writeSummarySheet(
            Workbook wb, Styles s, Map<String, Object> report, NursingActivityReportService.ReportKind kind) {
        Sheet sheet = wb.createSheet("Tổng hợp");
        sheet.setDisplayGridlines(false);
        int lastCol = 7;
        int r = writeFormalHeader(sheet, s, report, lastCol);
        r += 1;
        r = writeSectionBanner(sheet, s, r, lastCol, "I. CHỈ SỐ TỔNG HỢP");
        r += 1;
        r = writeKpiCards(sheet, s, r, lastCol, report, kind);
        r += 2;
        r = writeFootnote(sheet, s, r, lastCol,
                "Ghi chú: Báo cáo tự động tính từ báo cáo hoạt động điều dưỡng hằng ngày. Không nhập tay các chỉ số.");
        r += 2;
        writeSignatureBlock(sheet, s, r, lastCol);
        for (int i = 0; i <= lastCol; i++) {
            sheet.setColumnWidth(i, i == 0 ? 3200 : 4200);
        }
    }

    @SuppressWarnings("unchecked")
    private void writeDeptSheet(
            Workbook wb, Styles s, Map<String, Object> report, NursingActivityReportService.ReportKind kind) {
        Sheet sheet = wb.createSheet("Theo khoa");
        sheet.setDisplayGridlines(false);
        String[] headers = deptHeaders(kind);
        int lastCol = headers.length - 1;
        int r = writeFormalHeader(sheet, s, report, lastCol);
        r += 1;
        r = writeSectionBanner(sheet, s, r, lastCol, "II. THỐNG KÊ THEO KHOA");
        r += 1;

        List<Map<String, Object>> rows = kind == NursingActivityReportService.ReportKind.OVERVIEW
                ? (List<Map<String, Object>>) report.get("summaryTable")
                : (List<Map<String, Object>>) report.get("byDepartment");

        int headerRow = r;
        Row header = sheet.createRow(r++);
        header.setHeightInPoints(28f);
        for (int i = 0; i < headers.length; i++) {
            Cell c = header.createCell(i);
            c.setCellValue(headers[i]);
            c.setCellStyle(s.header);
        }

        if (rows == null || rows.isEmpty()) {
            Row empty = sheet.createRow(r);
            empty.setHeightInPoints(24f);
            Cell cell = empty.createCell(0);
            cell.setCellValue("Chưa có dữ liệu");
            cell.setCellStyle(s.center);
            sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        } else {
            int stt = 1;
            for (Map<String, Object> row : rows) {
                Row dr = sheet.createRow(r++);
                dr.setHeightInPoints(21f);
                String[] vals = deptRowValues(row, kind, stt++);
                boolean zebra = stt % 2 == 0;
                for (int i = 0; i < vals.length; i++) {
                    Cell c = dr.createCell(i);
                    c.setCellValue(vals[i]);
                    c.setCellStyle(i == 0 || i == 1
                            ? (zebra ? (i == 0 ? s.centerZebra : s.textZebra) : (i == 0 ? s.center : s.text))
                            : (zebra ? s.centerZebra : s.center));
                }
            }
        }

        sheet.createFreezePane(0, headerRow + 1);
        sheet.setRepeatingRows(new CellRangeAddress(headerRow, headerRow, 0, lastCol));
        setDeptWidths(sheet, kind);
    }

    private void setDeptWidths(Sheet sheet, NursingActivityReportService.ReportKind kind) {
        int[] widths = switch (kind) {
            case OVERVIEW -> new int[]{2200, 11000, 3800, 4200, 3800, 4200, 4200, 4200, 3800};
            case FALLS, PRESSURE_ULCER -> new int[]{2200, 11000, 3800, 4200, 4200, 3800, 4200};
            case NURSE_BED -> new int[]{2200, 12000, 4200, 4200, 4800};
            case ID_MIXUP, MEDICATION_ERROR -> new int[]{2200, 12000, 4200, 4800, 4800};
        };
        for (int i = 0; i < widths.length; i++) {
            sheet.setColumnWidth(i, widths[i]);
        }
    }

    private int writeFormalHeader(Sheet sheet, Styles s, Map<String, Object> report, int lastCol) {
        int r = 0;
        Row org = sheet.createRow(r++);
        org.setHeightInPoints(20f);
        mergeCenter(sheet, org, 0, lastCol, "BỆNH VIỆN MINH AN", s.orgName);

        Row dept = sheet.createRow(r++);
        dept.setHeightInPoints(18f);
        mergeCenter(sheet, dept, 0, lastCol, "PHÒNG ĐIỀU DƯỠNG", s.orgSub);

        Row line = sheet.createRow(r++);
        line.setHeightInPoints(6f);
        for (int c = 0; c <= lastCol; c++) {
            Cell cell = line.createCell(c);
            cell.setCellStyle(s.divider);
        }
        sheet.addMergedRegion(new CellRangeAddress(r - 1, r - 1, 0, lastCol));

        Row title = sheet.createRow(r++);
        title.setHeightInPoints(24f);
        mergeCenter(sheet, title, 0, lastCol, String.valueOf(report.get("reportTitle")).toUpperCase(Locale.ROOT), s.reportTitle);

        Row sub = sheet.createRow(r++);
        sub.setHeightInPoints(16f);
        mergeCenter(sheet, sub, 0, lastCol, "(Báo cáo hoạt động điều dưỡng — tự động từ hệ thống HRM)", s.reportSub);

        return writeMetaGrid(sheet, s, r, lastCol, report);
    }

    private int writeMetaGrid(Sheet sheet, Styles s, int r, int lastCol, Map<String, Object> report) {
        int split = Math.max(1, lastCol / 2);
        r += 1;
        Row row1 = sheet.createRow(r++);
        row1.setHeightInPoints(20f);
        writeMetaField(sheet, row1, s, 0, 1, split, "Kỳ báo cáo",
                str(report.get("fromLabel")) + " – " + str(report.get("toLabel")));
        writeMetaField(sheet, row1, s, split + 1, split + 2, lastCol, "Phạm vi", str(report.get("departmentName")));

        Row row2 = sheet.createRow(r++);
        row2.setHeightInPoints(20f);
        writeMetaField(sheet, row2, s, 0, 1, split, "Ngày xuất", LocalDate.now().format(DMY));
        writeMetaField(sheet, row2, s, split + 1, split + 2, lastCol, "Loại báo cáo", str(report.get("reportTitle")));
        return r;
    }

    private void writeMetaField(
            Sheet sheet, Row row, Styles s, int labelCol, int valueStart, int valueEnd, String label, String value) {
        Cell lc = row.createCell(labelCol);
        lc.setCellValue(label);
        lc.setCellStyle(s.metaLabel);
        Cell vc = row.createCell(valueStart);
        vc.setCellValue(value);
        vc.setCellStyle(s.metaValue);
        if (valueEnd > valueStart) {
            sheet.addMergedRegion(new CellRangeAddress(row.getRowNum(), row.getRowNum(), valueStart, valueEnd));
        }
    }

    private int writeSectionBanner(Sheet sheet, Styles s, int r, int lastCol, String text) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(24f);
        Cell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(s.section);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    @SuppressWarnings("unchecked")
    private int writeKpiCards(
            Sheet sheet, Styles s, int startRow, int lastCol, Map<String, Object> report,
            NursingActivityReportService.ReportKind kind) {
        List<String[]> cards = new ArrayList<>();
        if (kind == NursingActivityReportService.ReportKind.OVERVIEW) {
            Map<String, Object> ov = (Map<String, Object>) report.get("overviewKpi");
            if (ov != null) {
                cards.add(new String[]{"Té ngã", nested(ov, "falls", "rateLabel")});
                cards.add(new String[]{"Loét tì đè", nested(ov, "pressureUlcers", "rateLabel")});
                cards.add(new String[]{"ĐD/NB", nested(ov, "nurseBed", "ratioLabel")});
                cards.add(new String[]{"Nhầm NB", nested(ov, "idMixups", "frequencyLabel")});
                cards.add(new String[]{"Sai sót thuốc", nested(ov, "medicationErrors", "rateLabel")});
            }
        } else {
            Map<String, Object> kpi = (Map<String, Object>) report.get("kpi");
            if (kpi != null) {
                switch (kind) {
                    case FALLS -> {
                        cards.add(new String[]{"Ca té ngã", str(kpi.get("falls"))});
                        cards.add(new String[]{"NB nội trú", str(kpi.get("inpatients"))});
                        cards.add(new String[]{"Tỷ lệ té ngã", str(kpi.get("fallRateLabel"))});
                        cards.add(new String[]{"Tần suất/1.000", str(kpi.get("fallFrequencyLabel"))});
                    }
                    case PRESSURE_ULCER -> {
                        cards.add(new String[]{"Ca loét mới", str(kpi.get("newPressureUlcers"))});
                        cards.add(new String[]{"NB nội trú", str(kpi.get("inpatients"))});
                        cards.add(new String[]{"Tỷ lệ loét", str(kpi.get("pressureUlcerRateLabel"))});
                        cards.add(new String[]{"Tần suất/1.000", str(kpi.get("pressureUlcerFrequencyLabel"))});
                    }
                    case NURSE_BED -> {
                        cards.add(new String[]{"ĐD đi làm", str(kpi.get("workingStaff"))});
                        cards.add(new String[]{"NB nội trú", str(kpi.get("inpatients"))});
                        cards.add(new String[]{"Tỷ lệ ĐD/NB", str(kpi.get("nurseBedRatioLabel"))});
                    }
                    case ID_MIXUP -> {
                        cards.add(new String[]{"Số trường hợp", str(kpi.get("idMixups"))});
                        cards.add(new String[]{"Ngày nằm viện", str(kpi.get("inpatientTreatmentDays"))});
                        cards.add(new String[]{"Tần suất/1.000", str(kpi.get("idMixupFrequencyLabel"))});
                    }
                    case MEDICATION_ERROR -> {
                        cards.add(new String[]{"NB sai sót", str(kpi.get("medicationErrors"))});
                        cards.add(new String[]{"NB nội trú", str(kpi.get("inpatients"))});
                        cards.add(new String[]{"Tỷ lệ sai sót", str(kpi.get("medicationErrorRateLabel"))});
                    }
                    default -> {}
                }
            }
        }
        if (cards.isEmpty()) {
            Row empty = sheet.createRow(startRow);
            Cell c = empty.createCell(0);
            c.setCellValue("Chưa có chỉ số");
            c.setCellStyle(s.center);
            sheet.addMergedRegion(new CellRangeAddress(startRow, startRow, 0, lastCol));
            return startRow + 1;
        }

        int r = startRow;
        Row labelRow = sheet.createRow(r++);
        labelRow.setHeightInPoints(22f);
        Row valueRow = sheet.createRow(r++);
        valueRow.setHeightInPoints(30f);
        int span = Math.max(1, (lastCol + 1) / cards.size());
        for (int i = 0; i < cards.size(); i++) {
            int c0 = i * span;
            int c1 = Math.min(lastCol, (i == cards.size() - 1) ? lastCol : c0 + span - 1);
            Cell lc = labelRow.createCell(c0);
            lc.setCellValue(cards.get(i)[0].toUpperCase(Locale.ROOT));
            lc.setCellStyle(s.kpiLabel);
            if (c1 > c0) sheet.addMergedRegion(new CellRangeAddress(startRow, startRow, c0, c1));

            Cell vc = valueRow.createCell(c0);
            vc.setCellValue(cards.get(i)[1]);
            vc.setCellStyle(s.kpiValue);
            if (c1 > c0) sheet.addMergedRegion(new CellRangeAddress(startRow + 1, startRow + 1, c0, c1));
        }

        if (kind == NursingActivityReportService.ReportKind.OVERVIEW) {
            Map<String, Object> ov = (Map<String, Object>) report.get("overviewKpi");
            if (ov != null) {
                r += 1;
                r = writeSectionBanner(sheet, s, r, lastCol, "Chi tiết tần suất / tỷ lệ phụ");
                r += 1;
                r = rawRow(sheet, s, r, lastCol, "Té ngã — Tần suất", nested(ov, "falls", "frequencyLabel"));
                r = rawRow(sheet, s, r, lastCol, "Loét tì đè — Tần suất", nested(ov, "pressureUlcers", "frequencyLabel"));
            }
        }
        return r;
    }

    private int rawRow(Sheet sheet, Styles s, int r, int lastCol, String label, String value) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(20f);
        Cell lc = row.createCell(0);
        lc.setCellValue(label);
        lc.setCellStyle(s.metaLabel);
        Cell vc = row.createCell(1);
        vc.setCellValue(value);
        vc.setCellStyle(s.metaValue);
        if (lastCol > 1) {
            sheet.addMergedRegion(new CellRangeAddress(r, r, 1, lastCol));
        }
        return r + 1;
    }

    private void writeSignatureBlock(Sheet sheet, Styles s, int r, int lastCol) {
        int mid = Math.max(1, lastCol / 2);
        Row title = sheet.createRow(r);
        title.setHeightInPoints(18f);
        mergeCenter(sheet, title, 0, mid - 1, "Người lập báo cáo", s.signTitle);
        mergeCenter(sheet, title, mid + 1, lastCol, "Trưởng khoa / Phụ trách", s.signTitle);

        Row space = sheet.createRow(r + 3);
        space.setHeightInPoints(36f);

        Row note = sheet.createRow(r + 4);
        note.setHeightInPoints(18f);
        mergeCenter(sheet, note, 0, mid - 1, "(Ký, ghi rõ họ tên)", s.signNote);
        mergeCenter(sheet, note, mid + 1, lastCol, "(Ký, ghi rõ họ tên)", s.signNote);
    }

    private int writeFootnote(Sheet sheet, Styles s, int r, int lastCol, String text) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(18f);
        Cell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(s.footnote);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    private void mergeCenter(Sheet sheet, Row row, int c0, int c1, String text, XSSFCellStyle style) {
        if (c1 < c0) return;
        Cell cell = row.createCell(c0);
        cell.setCellValue(text);
        cell.setCellStyle(style);
        if (c1 > c0) {
            sheet.addMergedRegion(new CellRangeAddress(row.getRowNum(), row.getRowNum(), c0, c1));
        }
    }

    private String[] deptHeaders(NursingActivityReportService.ReportKind kind) {
        return switch (kind) {
            case OVERVIEW -> new String[]{"STT", "Khoa", "Té ngã %", "Té ngã/1000", "Loét %", "Loét/1000", "ĐD/NB", "Nhầm/1000", "Sai sót %"};
            case FALLS -> new String[]{"STT", "Khoa", "Ca té ngã", "NB nội trú", "Ngày nằm viện", "Tỷ lệ", "Tần suất/1000"};
            case PRESSURE_ULCER -> new String[]{"STT", "Khoa", "Ca loét mới", "NB nội trú", "Ngày nằm viện", "Tỷ lệ", "Tần suất/1000"};
            case NURSE_BED -> new String[]{"STT", "Khoa", "ĐD đi làm", "NB nội trú", "Tỷ lệ ĐD/NB"};
            case ID_MIXUP -> new String[]{"STT", "Khoa", "Số trường hợp", "Ngày nằm viện", "Tần suất/1000"};
            case MEDICATION_ERROR -> new String[]{"STT", "Khoa", "NB sai sót", "NB nội trú", "Tỷ lệ sai sót"};
        };
    }

    private String[] deptRowValues(Map<String, Object> row, NursingActivityReportService.ReportKind kind, int stt) {
        if (kind == NursingActivityReportService.ReportKind.OVERVIEW) {
            return new String[]{
                    String.valueOf(stt),
                    str(row.get("departmentName")),
                    str(row.get("fallRateLabel")), str(row.get("fallFrequencyLabel")),
                    str(row.get("pressureUlcerRateLabel")), str(row.get("pressureUlcerFrequencyLabel")),
                    str(row.get("nurseBedRatioLabel")), str(row.get("idMixupFrequencyLabel")),
                    str(row.get("medicationErrorRateLabel")),
            };
        }
        return switch (kind) {
            case FALLS -> new String[]{
                    String.valueOf(stt), str(row.get("departmentName")), str(row.get("falls")), str(row.get("inpatients")),
                    str(row.get("inpatientTreatmentDays")), str(row.get("fallRateLabel")), str(row.get("fallFrequencyLabel")),
            };
            case PRESSURE_ULCER -> new String[]{
                    String.valueOf(stt), str(row.get("departmentName")), str(row.get("newPressureUlcers")), str(row.get("inpatients")),
                    str(row.get("inpatientTreatmentDays")), str(row.get("pressureUlcerRateLabel")),
                    str(row.get("pressureUlcerFrequencyLabel")),
            };
            case NURSE_BED -> new String[]{
                    String.valueOf(stt), str(row.get("departmentName")), str(row.get("workingStaff")),
                    str(row.get("inpatients")), str(row.get("nurseBedRatioLabel")),
            };
            case ID_MIXUP -> new String[]{
                    String.valueOf(stt), str(row.get("departmentName")), str(row.get("idMixups")),
                    str(row.get("inpatientTreatmentDays")), str(row.get("idMixupFrequencyLabel")),
            };
            case MEDICATION_ERROR -> new String[]{
                    String.valueOf(stt), str(row.get("departmentName")), str(row.get("medicationErrors")),
                    str(row.get("inpatients")), str(row.get("medicationErrorRateLabel")),
            };
            default -> new String[]{String.valueOf(stt), str(row.get("departmentName"))};
        };
    }

    @SuppressWarnings("unchecked")
    private static String nested(Map<String, Object> group, String key, String field) {
        Map<String, Object> item = (Map<String, Object>) group.get(key);
        return item != null ? str(item.get(field)) : "—";
    }

    private static String str(Object o) {
        return o == null ? "—" : String.valueOf(o);
    }

    private static class Styles {
        final XSSFCellStyle orgName, orgSub, reportTitle, reportSub, divider, section, header;
        final XSSFCellStyle metaLabel, metaValue, kpiLabel, kpiValue;
        final XSSFCellStyle text, textZebra, center, centerZebra, footnote, signTitle, signNote;

        Styles(XSSFWorkbook wb) {
            orgName = centerNoBorder(wb, font(wb, 13, true, INK));
            orgSub = centerNoBorder(wb, font(wb, 11, true, BRAND));
            reportTitle = centerNoBorder(wb, font(wb, 14, true, BRAND_DARK));
            reportSub = centerNoBorder(wb, font(wb, 9, false, MUTED));
            divider = divider(wb);
            section = fill(wb, font(wb, 11, true, BRAND_DARK), BRAND_LIGHT, HorizontalAlignment.LEFT);
            header = fill(wb, font(wb, 10, true, "FFFFFF"), BRAND, HorizontalAlignment.CENTER);
            metaLabel = fill(wb, font(wb, 9, true, BRAND_DARK), BRAND_LIGHT, HorizontalAlignment.LEFT);
            metaValue = bordered(wb, font(wb, 10, false, INK), HorizontalAlignment.LEFT, null);
            kpiLabel = fill(wb, font(wb, 9, true, MUTED), "F1F5F9", HorizontalAlignment.CENTER);
            kpiValue = fill(wb, font(wb, 12, true, BRAND), KPI_VALUE_BG, HorizontalAlignment.CENTER);
            text = bordered(wb, font(wb, 10, false, INK), HorizontalAlignment.LEFT, null);
            textZebra = bordered(wb, font(wb, 10, false, INK), HorizontalAlignment.LEFT, ZEBRA);
            center = bordered(wb, font(wb, 10, false, INK), HorizontalAlignment.CENTER, null);
            centerZebra = bordered(wb, font(wb, 10, false, INK), HorizontalAlignment.CENTER, ZEBRA);
            footnote = leftNoBorder(wb, font(wb, 9, false, MUTED));
            signTitle = centerNoBorder(wb, font(wb, 10, true, INK));
            signNote = centerNoBorder(wb, font(wb, 9, false, MUTED));
        }

        private static XSSFFont font(XSSFWorkbook wb, int size, boolean bold, String hex) {
            XSSFFont f = wb.createFont();
            f.setFontName(FONT);
            f.setFontHeightInPoints((short) size);
            f.setBold(bold);
            f.setColor(new XSSFColor(hexToBytes(hex), null));
            return f;
        }

        private static XSSFCellStyle centerNoBorder(XSSFWorkbook wb, XSSFFont font) {
            XSSFCellStyle st = wb.createCellStyle();
            st.setFont(font);
            st.setAlignment(HorizontalAlignment.CENTER);
            st.setVerticalAlignment(VerticalAlignment.CENTER);
            return st;
        }

        private static XSSFCellStyle leftNoBorder(XSSFWorkbook wb, XSSFFont font) {
            XSSFCellStyle st = wb.createCellStyle();
            st.setFont(font);
            st.setAlignment(HorizontalAlignment.LEFT);
            st.setVerticalAlignment(VerticalAlignment.CENTER);
            st.setWrapText(true);
            return st;
        }

        private static XSSFCellStyle divider(XSSFWorkbook wb) {
            XSSFCellStyle st = wb.createCellStyle();
            XSSFColor c = new XSSFColor(hexToBytes(BRAND), null);
            st.setBorderBottom(BorderStyle.MEDIUM);
            st.setBottomBorderColor(c);
            return st;
        }

        private static XSSFCellStyle fill(
                XSSFWorkbook wb, XSSFFont font, String bg, HorizontalAlignment align) {
            XSSFCellStyle st = bordered(wb, font, align, bg);
            return st;
        }

        private static XSSFCellStyle bordered(
                XSSFWorkbook wb, XSSFFont font, HorizontalAlignment align, String bg) {
            XSSFCellStyle st = wb.createCellStyle();
            st.setFont(font);
            st.setAlignment(align);
            st.setVerticalAlignment(VerticalAlignment.CENTER);
            st.setWrapText(true);
            XSSFColor border = new XSSFColor(hexToBytes(BORDER), null);
            st.setBorderTop(BorderStyle.THIN);
            st.setBorderBottom(BorderStyle.THIN);
            st.setBorderLeft(BorderStyle.THIN);
            st.setBorderRight(BorderStyle.THIN);
            st.setTopBorderColor(border);
            st.setBottomBorderColor(border);
            st.setLeftBorderColor(border);
            st.setRightBorderColor(border);
            if (bg != null) {
                st.setFillForegroundColor(new XSSFColor(hexToBytes(bg), null));
                st.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            }
            return st;
        }

        private static byte[] hexToBytes(String hex) {
            return new byte[]{
                    (byte) Integer.parseInt(hex.substring(0, 2), 16),
                    (byte) Integer.parseInt(hex.substring(2, 4), 16),
                    (byte) Integer.parseInt(hex.substring(4, 6), 16),
            };
        }
    }
}
