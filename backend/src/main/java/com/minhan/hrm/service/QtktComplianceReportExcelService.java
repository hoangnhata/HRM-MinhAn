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
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class QtktComplianceReportExcelService {

    private static final String FONT = "Times New Roman";
    private static final String BRAND = "0F4C5C";
    private static final String BRAND_LIGHT = "E0F2F6";
    private static final String INK = "1C1C1C";
    private static final String MUTED = "525252";
    private static final String BORDER = "B4B4B4";
    private static final String ZEBRA = "F8F8F8";
    private static final String PASS_BG = "E8F5E9";
    private static final String PASS_FG = "1B5E20";
    private static final String FAIL_BG = "FFEBEE";
    private static final String FAIL_FG = "B71C1C";
    private static final String KPI_LABEL_BG = "E8E8E8";
    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final QtktComplianceReportService reportService;

    public byte[] exportHandHygiene(
            LocalDate from, LocalDate to, Long departmentId, Long employeeId,
            String search, String resultFilter, String sortDir) {
        Map<String, Object> report = reportService.handHygieneReport(
                from, to, departmentId, employeeId, search, resultFilter, sortDir, 0, 100_000);
        return buildWorkbook(report, Mode.HAND_HYGIENE);
    }

    public byte[] exportTechnical(
            LocalDate from, LocalDate to, Long departmentId, Long employeeId, String procedureCode,
            String search, String resultFilter, String sortDir) {
        Map<String, Object> report = reportService.technicalReport(
                from, to, departmentId, employeeId, procedureCode, search, resultFilter, sortDir, 0, 100_000);
        return buildWorkbook(report, Mode.TECHNICAL);
    }

    public byte[] exportGdsk(
            LocalDate from, LocalDate to, Long departmentId, Long employeeId,
            String search, String resultFilter, String sortDir) {
        Map<String, Object> report = reportService.gdskReport(
                from, to, departmentId, employeeId, search, resultFilter, sortDir, 0, 100_000);
        return buildWorkbook(report, Mode.GDSK);
    }

    private enum Mode { HAND_HYGIENE, TECHNICAL, GDSK }

    @SuppressWarnings("unchecked")
    private byte[] buildWorkbook(Map<String, Object> report, Mode mode) {
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Styles s = new Styles(wb);
            writeSummarySheet(wb, s, report);
            writeDeptSheet(wb, s, report);
            if (mode == Mode.HAND_HYGIENE) {
                writeContextSheet(wb, s, (List<Map<String, Object>>) report.get("byCheckContext"));
            } else if (mode == Mode.TECHNICAL) {
                writeProcedureSheet(wb, s, (List<Map<String, Object>>) report.get("byProcedure"));
            }
            writeDetailSheet(wb, s, (Map<String, Object>) report.get("details"), mode);
            applyPrintSetup(wb);
            wb.write(out);
            return out.toByteArray();
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file Excel: " + ex.getMessage());
        }
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
            footer.setLeft("Bệnh viện Minh An — HRM");
            footer.setCenter("&A");
            footer.setRight("Trang &P / &N");
        }
    }

    private void writeSummarySheet(Workbook wb, Styles s, Map<String, Object> report) {
        Sheet sheet = wb.createSheet("Tổng hợp");
        sheet.setDisplayGridlines(false);
        @SuppressWarnings("unchecked")
        Map<String, Object> kpi = (Map<String, Object>) report.get("kpi");
        int lastCol = 7;
        int r = writeFormalHeader(sheet, s, report, lastCol);
        r += 1;
        r = writeSectionBanner(sheet, s, r, lastCol, "I. TÓM TẮT CHỈ SỐ");
        r += 1;
        r = writeKpiCards(sheet, s, r, lastCol, kpi);
        r += 2;
        r = writeFootnote(sheet, s, r, lastCol,
                report.get("formulaNote") != null
                        ? String.valueOf(report.get("formulaNote"))
                        : "Ghi chú: Báo cáo tự động tổng hợp từ phiếu đánh giá đã hoàn thành (SUBMITTED). Không nhập tay tỷ lệ tuân thủ.");
        r += 2;
        writeSignatureBlock(sheet, s, r, lastCol);
        autosizeSummaryColumns(sheet, lastCol);
    }

    private void writeDeptSheet(Workbook wb, Styles s, Map<String, Object> report) {
        Sheet sheet = wb.createSheet("Theo khoa");
        sheet.setDisplayGridlines(false);
        int lastCol = 5;
        int r = writeFormalHeader(sheet, s, report, lastCol);
        r += 1;
        r = writeSectionBanner(sheet, s, r, lastCol, "II. THỐNG KÊ THEO KHOA");
        r += 1;
        String[] headers = {"STT", "Khoa", "Tổng đánh giá", "Đạt", "Không đạt", "Tỷ lệ tuân thủ"};
        writeIndexedTable(sheet, s, r, headers, (List<Map<String, Object>>) report.get("byDepartment"), (row, stt) -> {
            boolean total = Boolean.TRUE.equals(row.get("isTotal"));
            return new RowStyle[]{
                    cell(String.valueOf(stt), total ? s.totalCenter : s.center, HorizontalAlignment.CENTER),
                    cell(String.valueOf(row.get("departmentName")), total ? s.totalText : null, HorizontalAlignment.LEFT),
                    cellNum(row.get("total"), total ? s.totalCenter : s.center),
                    cellNum(row.get("passed"), s.passCenter),
                    cellNum(row.get("failed"), s.failCenter),
                    cell(formatRate(row.get("complianceRate")), total ? s.totalCenter : s.rate, HorizontalAlignment.CENTER),
            };
        }, true);
        setTableColumnWidths(sheet, new int[]{2200, 12000, 4200, 3200, 4200, 4800});
        sheet.setRepeatingRows(new CellRangeAddress(r, r, 0, headers.length - 1));
    }

    private void writeContextSheet(Workbook wb, Styles s, List<Map<String, Object>> rows) {
        Sheet sheet = wb.createSheet("Theo thời điểm");
        sheet.setDisplayGridlines(false);
        int lastCol = 5;
        int r = writeSectionBanner(sheet, s, 0, lastCol, "III. THỐNG KÊ THEO THỜI ĐIỂM VỆ SINH TAY");
        r += 1;
        String[] headers = {"STT", "Thời điểm", "Tổng đánh giá", "Đạt", "Không đạt", "Tuân thủ"};
        writeIndexedTable(sheet, s, r, headers, rows, (row, stt) -> new RowStyle[]{
                cell(String.valueOf(stt), s.center, HorizontalAlignment.CENTER),
                cell(String.valueOf(row.get("checkContextLabel")), null, HorizontalAlignment.LEFT),
                cellNum(row.get("total"), s.center),
                cellNum(row.get("passed"), s.passCenter),
                cellNum(row.get("failed"), s.failCenter),
                cell(formatRate(row.get("complianceRate")), s.rate, HorizontalAlignment.CENTER),
        }, true);
        setTableColumnWidths(sheet, new int[]{2200, 14000, 4200, 3200, 4200, 4800});
        sheet.setRepeatingRows(new CellRangeAddress(r, r, 0, headers.length - 1));
    }

    private void writeProcedureSheet(Workbook wb, Styles s, List<Map<String, Object>> rows) {
        Sheet sheet = wb.createSheet("Theo quy trình");
        sheet.setDisplayGridlines(false);
        int lastCol = 5;
        int r = writeSectionBanner(sheet, s, 0, lastCol, "III. THỐNG KÊ THEO QUY TRÌNH KỸ THUẬT");
        r += 1;
        String[] headers = {"STT", "Quy trình", "Tổng đánh giá", "Đạt", "Không đạt", "Tỷ lệ"};
        writeIndexedTable(sheet, s, r, headers, rows, (row, stt) -> {
            boolean total = Boolean.TRUE.equals(row.get("isTotal"));
            return new RowStyle[]{
                    cell(String.valueOf(stt), total ? s.totalCenter : s.center, HorizontalAlignment.CENTER),
                    cell(String.valueOf(row.get("procedureName")), total ? s.totalText : null, HorizontalAlignment.LEFT),
                    cellNum(row.get("total"), total ? s.totalCenter : s.center),
                    cellNum(row.get("passed"), s.passCenter),
                    cellNum(row.get("failed"), s.failCenter),
                    cell(formatRate(row.get("complianceRate")), total ? s.totalCenter : s.rate, HorizontalAlignment.CENTER),
            };
        }, true);
        setTableColumnWidths(sheet, new int[]{2200, 12000, 4200, 3200, 4200, 4800});
        sheet.setRepeatingRows(new CellRangeAddress(r, r, 0, headers.length - 1));
    }

    @SuppressWarnings("unchecked")
    private void writeDetailSheet(Workbook wb, Styles s, Map<String, Object> details, Mode mode) {
        Sheet sheet = wb.createSheet("Chi tiết");
        sheet.setDisplayGridlines(false);
        int lastCol = 6;
        int r = writeSectionBanner(sheet, s, 0, lastCol, "IV. DANH SÁCH ĐÁNH GIÁ CHI TIẾT");
        r += 1;
        String[] headers = switch (mode) {
            case HAND_HYGIENE -> new String[]{"STT", "Ngày kiểm tra", "Khoa", "Nhân viên", "Thời điểm vệ sinh tay", "Điểm", "Kết quả"};
            case TECHNICAL -> new String[]{"STT", "Ngày", "Khoa", "Nhân viên", "Quy trình", "Điểm", "Kết quả"};
            case GDSK -> new String[]{"STT", "Ngày", "Khoa", "Nhân viên", "Mã bệnh nhân", "Điểm", "Kết quả"};
        };
        List<Map<String, Object>> items = (List<Map<String, Object>>) details.get("items");
        writeIndexedTable(sheet, s, r, headers, items, (row, stt) -> {
            String result = String.valueOf(row.get("result"));
            String mid = switch (mode) {
                case HAND_HYGIENE -> String.valueOf(row.get("checkContextLabel") != null ? row.get("checkContextLabel") : "");
                case TECHNICAL -> String.valueOf(row.get("procedureName"));
                case GDSK -> String.valueOf(row.get("patientCode") != null ? row.get("patientCode") : "");
            };
            return new RowStyle[]{
                    cell(String.valueOf(stt), s.center, HorizontalAlignment.CENTER),
                    cell(String.valueOf(row.get("evalDateLabel")), null, HorizontalAlignment.CENTER),
                    cell(String.valueOf(row.get("departmentName")), null, HorizontalAlignment.LEFT),
                    cell(String.valueOf(row.get("employeeName")), null, HorizontalAlignment.LEFT),
                    cell(mid, null, HorizontalAlignment.LEFT),
                    cellNum(row.get("totalScore"), s.num2Bold),
                    cell(result, null, HorizontalAlignment.CENTER),
            };
        }, true);
        setTableColumnWidths(sheet, new int[]{2200, 4200, 9000, 8500, 11000, 3200, 4200});
        sheet.setRepeatingRows(new CellRangeAddress(r, r, 0, headers.length - 1));
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
        mergeCenter(sheet, sub, 0, lastCol, "(Báo cáo tự động từ hệ thống HRM)", s.reportSub);

        r = writeMetaGrid(sheet, s, r, lastCol, report);
        return r;
    }

    private int writeMetaGrid(Sheet sheet, Styles s, int r, int lastCol, Map<String, Object> report) {
        int split = Math.max(1, lastCol / 2);
        r += 1;
        Row row1 = sheet.createRow(r++);
        row1.setHeightInPoints(20f);
        writeMetaField(sheet, row1, s, 0, 1, split, "Kỳ báo cáo",
                formatIso(String.valueOf(report.get("from"))) + " – " + formatIso(String.valueOf(report.get("to"))));
        writeMetaField(sheet, row1, s, split + 1, split + 2, lastCol, "Phạm vi", String.valueOf(report.get("departmentName")));

        Row row2 = sheet.createRow(r++);
        row2.setHeightInPoints(20f);
        writeMetaField(sheet, row2, s, 0, 1, split, "Ngày xuất", LocalDate.now().format(DMY));
        writeMetaField(sheet, row2, s, split + 1, split + 2, lastCol, "Loại báo cáo", String.valueOf(report.get("reportTitle")));
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

    private void mergeCenter(Sheet sheet, Row row, int c0, int c1, String text, XSSFCellStyle style) {
        Cell cell = row.createCell(c0);
        cell.setCellValue(text);
        cell.setCellStyle(style);
        if (c1 > c0) {
            sheet.addMergedRegion(new CellRangeAddress(row.getRowNum(), row.getRowNum(), c0, c1));
        }
    }

    @SuppressWarnings("unchecked")
    private int writeKpiCards(Sheet sheet, Styles s, int startRow, int lastCol, Map<String, Object> kpi) {
        String[][] cards = {
                {"Tổng lần đánh giá", String.valueOf(kpi.get("total"))},
                {"Số lần đạt", String.valueOf(kpi.get("passed"))},
                {"Số lần không đạt", String.valueOf(kpi.get("failed"))},
                {"Tỷ lệ tuân thủ", String.valueOf(kpi.get("complianceRateLabel"))},
        };
        int r = startRow;
        Row labelRow = sheet.createRow(r++);
        labelRow.setHeightInPoints(22f);
        Row valueRow = sheet.createRow(r++);
        valueRow.setHeightInPoints(32f);
        int span = Math.max(1, (lastCol + 1) / cards.length);
        for (int i = 0; i < cards.length; i++) {
            int c0 = i * span;
            int c1 = Math.min(lastCol, c0 + span - 1);
            Cell lc = labelRow.createCell(c0);
            lc.setCellValue(cards[i][0]);
            lc.setCellStyle(s.kpiLabel);
            if (c1 > c0) sheet.addMergedRegion(new CellRangeAddress(startRow, startRow, c0, c1));

            Cell vc = valueRow.createCell(c0);
            vc.setCellValue(cards[i][1]);
            XSSFCellStyle vs = switch (i) {
                case 1 -> s.kpiPass;
                case 2 -> s.kpiFail;
                case 3 -> s.kpiRate;
                default -> s.kpiValue;
            };
            vc.setCellStyle(vs);
            if (c1 > c0) sheet.addMergedRegion(new CellRangeAddress(startRow + 1, startRow + 1, c0, c1));
        }
        return r;
    }

    private void writeSignatureBlock(Sheet sheet, Styles s, int r, int lastCol) {
        int signCol = Math.max(4, lastCol - 3);
        Row title = sheet.createRow(r);
        title.setHeightInPoints(18f);
        mergeCenter(sheet, title, signCol, lastCol, "Trưởng khoa / Phụ trách", s.signTitle);

        Row space = sheet.createRow(r + 3);
        space.setHeightInPoints(40f);

        Row note = sheet.createRow(r + 4);
        note.setHeightInPoints(18f);
        mergeCenter(sheet, note, signCol, lastCol, "(Ký, ghi rõ họ tên)", s.signNote);
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

    @FunctionalInterface
    private interface IndexedRowMapper {
        RowStyle[] map(Map<String, Object> row, int stt);
    }

    private record RowStyle(String text, XSSFCellStyle style, HorizontalAlignment align, boolean numeric) {
        RowStyle(String text, XSSFCellStyle style, HorizontalAlignment align) {
            this(text, style, align, false);
        }
    }

    private RowStyle cell(String text, XSSFCellStyle style, HorizontalAlignment align) {
        return new RowStyle(text, style, align);
    }

    private RowStyle cellNum(Object value, XSSFCellStyle style) {
        return new RowStyle(String.valueOf(value), style, HorizontalAlignment.CENTER, true);
    }

    private void writeIndexedTable(
            Sheet sheet, Styles s, int startRow, String[] headers, List<Map<String, Object>> rows,
            IndexedRowMapper mapper, boolean freezeHeader) {
        int r = startRow;
        Row header = sheet.createRow(r++);
        header.setHeightInPoints(28f);
        for (int c = 0; c < headers.length; c++) {
            Cell cell = header.createCell(c);
            cell.setCellValue(headers[c]);
            cell.setCellStyle(s.header);
        }

        if (rows == null || rows.isEmpty()) {
            Row empty = sheet.createRow(r);
            empty.setHeightInPoints(24f);
            Cell cell = empty.createCell(0);
            cell.setCellValue("Chưa có dữ liệu");
            cell.setCellStyle(s.center);
            sheet.addMergedRegion(new CellRangeAddress(r, r, 0, headers.length - 1));
            if (freezeHeader) sheet.createFreezePane(0, startRow + 1);
            return;
        }

        int idx = 1;
        for (Map<String, Object> row : rows) {
            Row dr = sheet.createRow(r++);
            dr.setHeightInPoints(21f);
            RowStyle[] cells = mapper.map(row, idx++);
            boolean zebra = idx % 2 == 0;
            for (int c = 0; c < cells.length; c++) {
                RowStyle rs = cells[c];
                Cell cell = dr.createCell(c);
                XSSFCellStyle base = pickBodyStyle(s, rs, zebra, c, headers.length);
                if (headers[c].contains("Kết quả")) {
                    base = resultStyle(s, rs.text, zebra);
                }
                cell.setCellStyle(base);
                if (rs.numeric) {
                    try {
                        cell.setCellValue(Double.parseDouble(rs.text));
                    } catch (Exception ex) {
                        cell.setCellValue(rs.text);
                    }
                } else {
                    cell.setCellValue(rs.text);
                }
            }
        }
        if (freezeHeader) {
            sheet.createFreezePane(0, startRow + 1);
        }
    }

    private XSSFCellStyle pickBodyStyle(Styles s, RowStyle rs, boolean zebra, int col, int len) {
        if (rs.style != null) return rs.style;
        boolean numericCol = col >= 2 && col < len - 1;
        if (rs.align == HorizontalAlignment.CENTER || numericCol) {
            return zebra ? s.centerZebra : s.center;
        }
        return zebra ? s.textZebra : s.text;
    }

    private XSSFCellStyle resultStyle(Styles s, String text, boolean zebra) {
        if ("Đạt".equalsIgnoreCase(text)) return zebra ? s.passTextZebra : s.passText;
        if (text != null && text.toLowerCase(Locale.ROOT).contains("không")) return zebra ? s.failTextZebra : s.failText;
        return zebra ? s.centerZebra : s.center;
    }

    private void autosizeSummaryColumns(Sheet sheet, int lastCol) {
        for (int i = 0; i <= lastCol; i++) {
            sheet.setColumnWidth(i, i == 0 ? 2400 : 4800);
        }
    }

    private void setTableColumnWidths(Sheet sheet, int[] widths) {
        for (int i = 0; i < widths.length; i++) {
            sheet.setColumnWidth(i, widths[i]);
        }
    }

    private String formatIso(String iso) {
        try {
            return LocalDate.parse(iso).format(DMY);
        } catch (Exception ex) {
            return iso;
        }
    }

    private String formatRate(Object rate) {
        if (rate == null) return "—";
        if (rate instanceof Number n) return String.format(Locale.ROOT, "%.2f%%", n.doubleValue());
        return String.valueOf(rate);
    }

    private static class Styles {
        final XSSFCellStyle orgName;
        final XSSFCellStyle orgSub;
        final XSSFCellStyle reportTitle;
        final XSSFCellStyle reportSub;
        final XSSFCellStyle divider;
        final XSSFCellStyle metaLabel;
        final XSSFCellStyle metaValue;
        final XSSFCellStyle section;
        final XSSFCellStyle footnote;
        final XSSFCellStyle header;
        final XSSFCellStyle text;
        final XSSFCellStyle textZebra;
        final XSSFCellStyle center;
        final XSSFCellStyle centerZebra;
        final XSSFCellStyle num2Bold;
        final XSSFCellStyle rate;
        final XSSFCellStyle passCenter;
        final XSSFCellStyle failCenter;
        final XSSFCellStyle passText;
        final XSSFCellStyle passTextZebra;
        final XSSFCellStyle failText;
        final XSSFCellStyle failTextZebra;
        final XSSFCellStyle totalText;
        final XSSFCellStyle totalCenter;
        final XSSFCellStyle kpiLabel;
        final XSSFCellStyle kpiValue;
        final XSSFCellStyle kpiPass;
        final XSSFCellStyle kpiFail;
        final XSSFCellStyle kpiRate;
        final XSSFCellStyle signTitle;
        final XSSFCellStyle signNote;

        Styles(XSSFWorkbook wb) {
            DataFormat fmt = wb.createDataFormat();
            short num2 = fmt.getFormat("0.00");

            orgName = centered(wb, font(wb, 13, true, INK));
            orgSub = centered(wb, font(wb, 11, true, BRAND));
            reportTitle = centered(wb, font(wb, 14, true, INK));
            reportSub = centered(wb, font(wb, 10, false, MUTED));
            divider = bottomRule(wb);
            metaLabel = plain(wb, font(wb, 10, true, INK), HorizontalAlignment.LEFT, BRAND_LIGHT, true);
            metaValue = plain(wb, font(wb, 10, false, INK), HorizontalAlignment.LEFT, "FFFFFF", true);
            section = sectionStyle(wb);
            footnote = plain(wb, font(wb, 9, false, MUTED), HorizontalAlignment.LEFT, null, false);
            header = fill(wb, font(wb, 10, true, "FFFFFF"), BRAND, HorizontalAlignment.CENTER, true);
            header.setWrapText(true);

            text = body(wb, font(wb, 10, false, INK), HorizontalAlignment.LEFT, null, (short) 0);
            textZebra = body(wb, font(wb, 10, false, INK), HorizontalAlignment.LEFT, ZEBRA, (short) 0);
            center = body(wb, font(wb, 10, false, INK), HorizontalAlignment.CENTER, null, (short) 0);
            centerZebra = body(wb, font(wb, 10, false, INK), HorizontalAlignment.CENTER, ZEBRA, (short) 0);
            num2Bold = body(wb, font(wb, 10, true, BRAND), HorizontalAlignment.CENTER, null, num2);
            rate = body(wb, font(wb, 10, true, BRAND), HorizontalAlignment.CENTER, null, (short) 0);

            passCenter = body(wb, font(wb, 10, true, PASS_FG), HorizontalAlignment.CENTER, PASS_BG, (short) 0);
            failCenter = body(wb, font(wb, 10, true, FAIL_FG), HorizontalAlignment.CENTER, FAIL_BG, (short) 0);
            passText = body(wb, font(wb, 10, true, PASS_FG), HorizontalAlignment.CENTER, PASS_BG, (short) 0);
            passTextZebra = body(wb, font(wb, 10, true, PASS_FG), HorizontalAlignment.CENTER, ZEBRA, (short) 0);
            failText = body(wb, font(wb, 10, true, FAIL_FG), HorizontalAlignment.CENTER, FAIL_BG, (short) 0);
            failTextZebra = body(wb, font(wb, 10, true, FAIL_FG), HorizontalAlignment.CENTER, ZEBRA, (short) 0);

            totalText = body(wb, font(wb, 10, true, INK), HorizontalAlignment.LEFT, KPI_LABEL_BG, (short) 0);
            totalCenter = body(wb, font(wb, 10, true, INK), HorizontalAlignment.CENTER, KPI_LABEL_BG, (short) 0);

            kpiLabel = fill(wb, font(wb, 9, true, MUTED), KPI_LABEL_BG, HorizontalAlignment.CENTER, true);
            kpiValue = fill(wb, font(wb, 16, true, INK), "FFFFFF", HorizontalAlignment.CENTER, true);
            kpiPass = fill(wb, font(wb, 16, true, PASS_FG), PASS_BG, HorizontalAlignment.CENTER, true);
            kpiFail = fill(wb, font(wb, 16, true, FAIL_FG), FAIL_BG, HorizontalAlignment.CENTER, true);
            kpiRate = fill(wb, font(wb, 16, true, BRAND), BRAND_LIGHT, HorizontalAlignment.CENTER, true);

            signTitle = centered(wb, font(wb, 11, true, INK));
            signNote = centered(wb, font(wb, 10, false, MUTED));
        }

        private static XSSFCellStyle centered(XSSFWorkbook wb, XSSFFont font) {
            XSSFCellStyle st = wb.createCellStyle();
            st.setFont(font);
            st.setAlignment(HorizontalAlignment.CENTER);
            st.setVerticalAlignment(VerticalAlignment.CENTER);
            st.setBorderLeft(BorderStyle.NONE);
            st.setBorderRight(BorderStyle.NONE);
            st.setBorderTop(BorderStyle.NONE);
            st.setBorderBottom(BorderStyle.NONE);
            return st;
        }

        private static XSSFCellStyle bottomRule(XSSFWorkbook wb) {
            XSSFCellStyle st = wb.createCellStyle();
            st.setBorderBottom(BorderStyle.MEDIUM);
            st.setBottomBorderColor(rgb(BRAND));
            return st;
        }

        private static XSSFCellStyle sectionStyle(XSSFWorkbook wb) {
            XSSFCellStyle st = plain(wb, font(wb, 11, true, BRAND), HorizontalAlignment.LEFT, BRAND_LIGHT, true);
            st.setIndention((short) 1);
            st.setBorderLeft(BorderStyle.MEDIUM);
            st.setLeftBorderColor(rgb(BRAND));
            return st;
        }

        private static XSSFFont font(XSSFWorkbook wb, int size, boolean bold, String hex) {
            XSSFFont f = wb.createFont();
            f.setFontName(FONT);
            f.setFontHeightInPoints((short) size);
            f.setBold(bold);
            f.setColor(rgb(hex));
            return f;
        }

        private static XSSFCellStyle plain(XSSFWorkbook wb, XSSFFont font, HorizontalAlignment align, String fill, boolean bordered) {
            XSSFCellStyle st = wb.createCellStyle();
            st.setFont(font);
            st.setAlignment(align);
            st.setVerticalAlignment(VerticalAlignment.CENTER);
            if (fill != null) {
                st.setFillForegroundColor(rgb(fill));
                st.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            }
            if (bordered) thin(st);
            st.setIndention((short) 1);
            st.setWrapText(true);
            return st;
        }

        private static XSSFCellStyle fill(XSSFWorkbook wb, XSSFFont font, String fill, HorizontalAlignment align, boolean bordered) {
            return plain(wb, font, align, fill, bordered);
        }

        private static XSSFCellStyle body(XSSFWorkbook wb, XSSFFont font, HorizontalAlignment align, String fill, short fmt) {
            XSSFCellStyle st = plain(wb, font, align, fill, true);
            if (fmt != 0) st.setDataFormat(fmt);
            return st;
        }

        private static void thin(XSSFCellStyle st) {
            XSSFColor c = rgb(BORDER);
            st.setBorderTop(BorderStyle.THIN);
            st.setBorderBottom(BorderStyle.THIN);
            st.setBorderLeft(BorderStyle.THIN);
            st.setBorderRight(BorderStyle.THIN);
            st.setTopBorderColor(c);
            st.setBottomBorderColor(c);
            st.setLeftBorderColor(c);
            st.setRightBorderColor(c);
        }

        private static XSSFColor rgb(String hex) {
            return new XSSFColor(hexToBytes(hex), null);
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
