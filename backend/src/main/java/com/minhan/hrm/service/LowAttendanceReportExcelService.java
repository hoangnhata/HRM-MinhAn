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
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Xuất danh sách nhân viên có công thấp trong tháng ra Excel (.xlsx),
 * nhóm theo khoa/phòng — mỗi khoa liệt kê nhân viên theo thứ tự công tăng dần để dễ theo dõi.
 */
@Service
@RequiredArgsConstructor
public class LowAttendanceReportExcelService {

    private final AttendanceSummaryService summaryService;

    private static final String FONT_NAME = "Times New Roman";

    private static final String BRAND = "0F766E";        // teal đậm
    private static final String BRAND_LIGHT = "CCFBF1";   // teal nhạt (dải tên khoa)
    private static final String HEADER_TEXT = "FFFFFF";
    private static final String ZEBRA = "F1F5F9";
    private static final String TOTAL_FILL = "E2E8F0";
    private static final String CRITICAL_FILL = "FEE2E2";  // đỏ nhạt — rất thấp (< ngưỡng/2)
    private static final String CRITICAL_TEXT = "991B1B";
    private static final String WARN_FILL = "FEF3C7";      // vàng nhạt — thấp (< ngưỡng)
    private static final String WARN_TEXT = "92400E";

    private static final Map<String, String> STATUS_LABEL = Map.of(
            "ACTIVE", "Chính thức",
            "PROBATION", "Thử việc",
            "INTERN", "Thực tập",
            "ON_LEAVE", "Nghỉ phép",
            "TERMINATED", "Nghỉ việc"
    );

    private static final String[] HEADERS = {
            "STT", "Mã NV", "Họ và tên", "Chức vụ", "SĐT", "Trạng thái",
            "Công chấm", "Công phép", "Công điều động", "Công trực", "Tổng công"
    };

    @Transactional(readOnly = true)
    public byte[] buildReport(int year, int month, Long departmentId, BigDecimal threshold) {
        if (month < 1 || month > 12) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Tháng không hợp lệ");
        }
        BigDecimal limit = threshold != null && threshold.compareTo(BigDecimal.ZERO) > 0
                ? threshold : BigDecimal.valueOf(5);
        List<Map<String, Object>> allRows = summaryService.monthReport(year, month, departmentId);

        List<Map<String, Object>> lowRows = allRows.stream()
                .filter(row -> num(row.get("totalWorkUnits")).compareTo(limit) < 0)
                .toList();

        Map<String, List<Map<String, Object>>> byDept = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        for (Map<String, Object> row : lowRows) {
            String dept = str(row.get("department"));
            byDept.computeIfAbsent(dept.isBlank() ? "Chưa xếp khoa/phòng" : dept, k -> new ArrayList<>()).add(row);
        }
        for (List<Map<String, Object>> group : byDept.values()) {
            group.sort(Comparator
                    .comparing((Map<String, Object> r) -> num(r.get("totalWorkUnits")))
                    .thenComparing(r -> str(r.get("fullName")), String.CASE_INSENSITIVE_ORDER));
        }

        String scopeName = departmentId == null || allRows.isEmpty()
                ? "Toàn bệnh viện"
                : str(allRows.get(0).get("department"));

        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Styles s = new Styles(wb);
            writeSheet(wb, s, byDept, lowRows.size(), year, month, scopeName, limit);
            wb.write(out);
            return out.toByteArray();
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file Excel: " + ex.getMessage());
        }
    }

    private void writeSheet(
            XSSFWorkbook wb, Styles s, Map<String, List<Map<String, Object>>> byDept,
            int totalCount, int year, int month, String scopeName, BigDecimal limit) {
        Sheet sheet = wb.createSheet("Công thấp trong tháng");
        sheet.setDisplayGridlines(false);
        int lastCol = HEADERS.length - 1;

        int r = 0;
        r = title(sheet, s, r, lastCol, "BỆNH VIỆN MINH AN");
        r = subtitle(sheet, s, r, lastCol,
                "DANH SÁCH NHÂN VIÊN CÔNG THẤP — THÁNG " + String.format("%02d/%d", month, year));
        r = meta(sheet, s, r, lastCol, "Phạm vi: " + scopeName
                + "     •     Ngưỡng: dưới " + fmt(limit) + " công"
                + "     •     Tổng số: " + totalCount + " nhân viên"
                + "     •     Xuất ngày: " + LocalDate.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy")));
        r++; // dòng trống

        int headerRowIdx = r;
        r = headerRow(sheet, s, r, lastCol);

        int idx = 1;
        for (Map.Entry<String, List<Map<String, Object>>> entry : byDept.entrySet()) {
            List<Map<String, Object>> group = entry.getValue();
            BigDecimal avg = group.stream()
                    .map(row -> num(row.get("totalWorkUnits")))
                    .reduce(BigDecimal.ZERO, BigDecimal::add)
                    .divide(BigDecimal.valueOf(group.size()), 2, RoundingMode.HALF_UP);

            Row bandRow = sheet.createRow(r++);
            bandRow.setHeightInPoints(22f);
            Cell bandCell = bandRow.createCell(0);
            bandCell.setCellValue("KHOA / PHÒNG: " + entry.getKey().toUpperCase(new Locale("vi", "VN"))
                    + "   ·   " + group.size() + " nhân viên dưới ngưỡng"
                    + "   ·   trung bình " + fmt(avg) + " công");
            bandCell.setCellStyle(s.band);
            sheet.addMergedRegion(new CellRangeAddress(bandRow.getRowNum(), bandRow.getRowNum(), 0, lastCol));

            int zebraIdx = 0;
            for (Map<String, Object> row : group) {
                boolean zebra = zebraIdx % 2 == 1;
                BigDecimal total = num(row.get("totalWorkUnits"));
                boolean critical = total.compareTo(limit.divide(BigDecimal.valueOf(2))) < 0;

                CellStyle textStyle = zebra ? s.textZebra : s.text;
                CellStyle centerStyle = zebra ? s.centerZebra : s.center;
                CellStyle numStyle = zebra ? s.num2Zebra : s.num2;
                CellStyle totalStyle = critical ? s.criticalNum : s.warnNum;

                Row dr = sheet.createRow(r++);
                dr.setHeightInPoints(18f);
                int c = 0;
                setCell(dr, c++, idx, centerStyle);
                setCell(dr, c++, str(row.get("employeeCode")), centerStyle);
                setCell(dr, c++, str(row.get("fullName")), textStyle);
                setCell(dr, c++, str(row.get("position")), textStyle);
                setCell(dr, c++, str(row.get("phone")), centerStyle);
                setCell(dr, c++, statusLabel(str(row.get("employeeStatus"))), centerStyle);
                setCell(dr, c++, num(row.get("clockedWorkUnits")), numStyle);
                setCell(dr, c++, num(row.get("leaveWorkUnits")), numStyle);
                setCell(dr, c++, num(row.get("deploymentWorkUnits")), numStyle);
                setCell(dr, c++, num(row.get("dutyWorkUnitsTotal")), numStyle);
                setCell(dr, c, total, totalStyle);
                idx++;
                zebraIdx++;
            }
        }

        // Dòng tổng cộng
        Row totalRow = sheet.createRow(r++);
        totalRow.setHeightInPoints(20f);
        setCell(totalRow, 0, "TỔNG CỘNG", s.totalText);
        for (int c = 1; c <= lastCol - 1; c++) {
            setCell(totalRow, c, "", s.totalText);
        }
        setCell(totalRow, lastCol, totalCount + " nhân viên", s.totalText);

        int[] widths = {1600, 2800, 6600, 5600, 3400, 3200, 2800, 2800, 3200, 2800, 2800};
        for (int c = 0; c <= lastCol; c++) {
            sheet.setColumnWidth(c, widths[c]);
        }

        sheet.createFreezePane(0, headerRowIdx + 1);

        r++;
        Row noteRow = sheet.createRow(r);
        Cell noteCell = noteRow.createCell(0);
        noteCell.setCellValue("Ghi chú: Danh sách chỉ gồm nhân viên có Tổng công trong tháng dưới " + fmt(limit)
                + " công, nhóm theo khoa/phòng và sắp xếp tăng dần theo công trong từng khoa. "
                + "Ô «Tổng công» tô đỏ = dưới " + fmt(limit.divide(BigDecimal.valueOf(2))) + " công (rất thấp), "
                + "tô vàng = còn lại dưới ngưỡng.");
        noteCell.setCellStyle(s.footnote);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
    }

    private int headerRow(Sheet sheet, Styles s, int r, int lastCol) {
        Row header = sheet.createRow(r++);
        header.setHeightInPoints(24f);
        for (int c = 0; c <= lastCol; c++) {
            Cell cell = header.createCell(c);
            cell.setCellValue(HEADERS[c]);
            cell.setCellStyle(s.header);
        }
        return r;
    }

    // ----------------------------------------------------------------- helpers

    private int title(Sheet sheet, Styles s, int r, int lastCol, String text) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(28f);
        Cell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(s.title);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    private int subtitle(Sheet sheet, Styles s, int r, int lastCol, String text) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(22f);
        Cell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(s.subtitle);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    private int meta(Sheet sheet, Styles s, int r, int lastCol, String text) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(18f);
        Cell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(s.meta);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    private static void setCell(Row row, int col, String value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(value != null ? value : "");
        cell.setCellStyle(style);
    }

    private static void setCell(Row row, int col, long value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(value);
        cell.setCellStyle(style);
    }

    private static void setCell(Row row, int col, BigDecimal value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(value != null ? value.doubleValue() : 0d);
        cell.setCellStyle(style);
    }

    private static String str(Object v) {
        return v != null ? String.valueOf(v) : "";
    }

    private static BigDecimal num(Object v) {
        if (v == null) return BigDecimal.ZERO;
        if (v instanceof BigDecimal b) return b;
        if (v instanceof Number n) return BigDecimal.valueOf(n.doubleValue());
        try {
            return new BigDecimal(v.toString());
        } catch (NumberFormatException ex) {
            return BigDecimal.ZERO;
        }
    }

    private static String fmt(BigDecimal v) {
        return v.setScale(2, RoundingMode.HALF_UP).stripTrailingZeros().toPlainString();
    }

    private static String statusLabel(String status) {
        if (status == null || status.isBlank()) return "";
        return STATUS_LABEL.getOrDefault(status, status);
    }

    /** Tập hợp các CellStyle dùng chung — font Times New Roman theo toàn bộ báo cáo. */
    private static final class Styles {
        final CellStyle title;
        final CellStyle subtitle;
        final CellStyle meta;
        final CellStyle footnote;
        final CellStyle header;
        final CellStyle band;

        final CellStyle text;
        final CellStyle center;
        final CellStyle num2;

        final CellStyle textZebra;
        final CellStyle centerZebra;
        final CellStyle num2Zebra;

        final CellStyle criticalNum;
        final CellStyle warnNum;

        final CellStyle totalText;

        Styles(XSSFWorkbook wb) {
            DataFormat fmt = wb.createDataFormat();
            short num2 = fmt.getFormat("0.00");

            XSSFFont titleFont = font(wb, 18, true, BRAND);
            XSSFFont subFont = font(wb, 13, true, "1F2937");
            XSSFFont metaFont = font(wb, 11, false, "475569");
            XSSFFont headFont = font(wb, 11, true, HEADER_TEXT);
            XSSFFont bandFont = font(wb, 11, true, "115E59");
            XSSFFont bodyFont = font(wb, 11, false, "1F2937");
            XSSFFont criticalFont = font(wb, 12, true, CRITICAL_TEXT);
            XSSFFont warnFont = font(wb, 12, true, WARN_TEXT);
            XSSFFont totalFont = font(wb, 11, true, "0F172A");
            XSSFFont footFont = font(wb, 10, false, "64748B");
            footFont.setItalic(true);

            this.title = base(wb, titleFont, HorizontalAlignment.CENTER, null, false);
            this.subtitle = base(wb, subFont, HorizontalAlignment.CENTER, null, false);
            this.meta = base(wb, metaFont, HorizontalAlignment.CENTER, null, false);
            this.footnote = base(wb, footFont, HorizontalAlignment.LEFT, null, false);

            this.header = base(wb, headFont, HorizontalAlignment.CENTER, BRAND, true);
            this.header.setVerticalAlignment(VerticalAlignment.CENTER);
            this.header.setWrapText(true);

            this.band = base(wb, bandFont, HorizontalAlignment.LEFT, BRAND_LIGHT, true);
            this.band.setVerticalAlignment(VerticalAlignment.CENTER);

            this.text = body(wb, bodyFont, HorizontalAlignment.LEFT, null, (short) 0);
            this.center = body(wb, bodyFont, HorizontalAlignment.CENTER, null, (short) 0);
            this.num2 = body(wb, bodyFont, HorizontalAlignment.CENTER, null, num2);

            this.textZebra = body(wb, bodyFont, HorizontalAlignment.LEFT, ZEBRA, (short) 0);
            this.centerZebra = body(wb, bodyFont, HorizontalAlignment.CENTER, ZEBRA, (short) 0);
            this.num2Zebra = body(wb, bodyFont, HorizontalAlignment.CENTER, ZEBRA, num2);

            this.criticalNum = body(wb, criticalFont, HorizontalAlignment.CENTER, CRITICAL_FILL, num2);
            this.warnNum = body(wb, warnFont, HorizontalAlignment.CENTER, WARN_FILL, num2);

            this.totalText = body(wb, totalFont, HorizontalAlignment.LEFT, TOTAL_FILL, (short) 0);
        }

        private static XSSFFont font(XSSFWorkbook wb, int size, boolean bold, String hex) {
            XSSFFont f = wb.createFont();
            f.setFontName(FONT_NAME);
            f.setFontHeightInPoints((short) size);
            f.setBold(bold);
            f.setColor(rgb(hex));
            return f;
        }

        private static XSSFCellStyle base(
                XSSFWorkbook wb, XSSFFont font, HorizontalAlignment align, String fillHex, boolean bordered) {
            XSSFCellStyle st = wb.createCellStyle();
            st.setFont(font);
            st.setAlignment(align);
            st.setVerticalAlignment(VerticalAlignment.CENTER);
            if (fillHex != null) {
                st.setFillForegroundColor(rgb(fillHex));
                st.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            }
            if (bordered) {
                thin(st);
            }
            return st;
        }

        private static XSSFCellStyle body(
                XSSFWorkbook wb, XSSFFont font, HorizontalAlignment align, String fillHex, short format) {
            XSSFCellStyle st = base(wb, font, align, fillHex, true);
            if (format != 0) {
                st.setDataFormat(format);
            }
            return st;
        }

        private static void thin(XSSFCellStyle st) {
            XSSFColor color = rgb("CBD5E1");
            st.setBorderTop(BorderStyle.THIN);
            st.setBorderBottom(BorderStyle.THIN);
            st.setBorderLeft(BorderStyle.THIN);
            st.setBorderRight(BorderStyle.THIN);
            st.setTopBorderColor(color);
            st.setBottomBorderColor(color);
            st.setLeftBorderColor(color);
            st.setRightBorderColor(color);
        }

        private static XSSFColor rgb(String hex) {
            int r = Integer.valueOf(hex.substring(0, 2), 16);
            int g = Integer.valueOf(hex.substring(2, 4), 16);
            int b = Integer.valueOf(hex.substring(4, 6), 16);
            return new XSSFColor(new byte[]{(byte) r, (byte) g, (byte) b}, null);
        }
    }
}
