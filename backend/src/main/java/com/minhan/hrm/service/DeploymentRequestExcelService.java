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
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Xuất danh sách đơn điều động ra Excel (.xlsx) — Times New Roman, bố cục hành chính.
 */
@Service
@RequiredArgsConstructor
public class DeploymentRequestExcelService {

    private final AttendanceWorkRequestService workRequestService;

    private static final String FONT_NAME = "Times New Roman";
    private static final String BRAND = "0F766E";
    private static final String HEADER_TEXT = "FFFFFF";
    private static final String ZEBRA = "F1F5F9";
    private static final String APPROVED_FILL = "DCFCE7";
    private static final String REJECTED_FILL = "FEE2E2";
    private static final String PENDING_FILL = "FEF3C7";

    private static final DateTimeFormatter DATE_VN = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    /** Ô số thực: giữ giá trị số để SUM/lọc được, hậu tố hiển thị theo định dạng. */
    private static final String FMT_HOURS = "0.##\" giờ\"";
    private static final String FMT_WORK_UNITS = "0.##\" công\"";

    private static final String[] HEADERS = {
            "STT",
            "Mã NV",
            "Họ và tên",
            "Chức vụ",
            "Khoa/phòng",
            "Nơi điều động",
            "Ngày điều động",
            "Giờ bắt đầu",
            "Giờ kết thúc",
            "Giờ chiều bắt đầu",
            "Giờ chiều kết thúc",
            "Hình thức",
            "Tổng giờ điều động",
            "Tổng giờ quy đổi",
            "Lý do",
            "Trạng thái",
            "Ngày gửi đơn"
    };

    @Transactional(readOnly = true)
    public byte[] buildReport(LocalDate fromDate, LocalDate toDate) {
        List<Map<String, Object>> rows = workRequestService.listDeploymentsForExport(fromDate, toDate);
        YearMonthRange range = resolveRange(fromDate, toDate);

        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Styles s = new Styles(wb);
            writeSheet(wb, s, rows, range.from(), range.to());
            wb.write(out);
            return out.toByteArray();
        } catch (ApiException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file Excel: " + ex.getMessage());
        }
    }

    private void writeSheet(XSSFWorkbook wb, Styles s, List<Map<String, Object>> rows, LocalDate from, LocalDate to) {
        Sheet sheet = wb.createSheet("Điều động");
        sheet.setDisplayGridlines(false);
        int lastCol = HEADERS.length - 1;

        int r = 0;
        r = title(sheet, s, r, lastCol, "BỆNH VIỆN MINH AN");
        r = subtitle(sheet, s, r, lastCol, "DANH SÁCH ĐƠN ĐIỀU ĐỘNG NHÂN VIÊN");
        r = meta(sheet, s, r, lastCol,
                "Thời gian điều động: " + from.format(DATE_VN) + " — " + to.format(DATE_VN)
                        + "     •     Tổng số: " + rows.size() + " đơn"
                        + "     •     Xuất ngày: " + LocalDate.now().format(DATE_VN));
        r++;

        int headerRowIdx = r;
        Row header = sheet.createRow(r++);
        header.setHeightInPoints(22f);
        for (int c = 0; c < HEADERS.length; c++) {
            Cell cell = header.createCell(c);
            cell.setCellValue(HEADERS[c]);
            cell.setCellStyle(s.header);
        }

        int idx = 1;
        for (Map<String, Object> row : rows) {
            boolean zebra = idx % 2 == 0;
            String status = str(row.get("status"));
            CellStyle text = statusStyle(s, status, zebra, false);
            CellStyle center = statusStyle(s, status, zebra, true);
            String fill = statusFill(status, zebra);

            Row excelRow = sheet.createRow(r++);
            excelRow.setHeightInPoints(18f);

            setCell(excelRow, 0, idx, center);
            setCell(excelRow, 1, str(row.get("employeeCode")), center);
            setCell(excelRow, 2, str(row.get("employeeName")), text);
            setCell(excelRow, 3, str(row.get("positionTitle")), text);
            setCell(excelRow, 4, str(row.get("department")), text);
            setCell(excelRow, 5, str(row.get("location")), text);
            setCell(excelRow, 6, formatDate(str(row.get("workDate"))), center);
            setCell(excelRow, 7, formatTime(str(row.get("requestedStart"))), center);
            setCell(excelRow, 8, formatTime(str(row.get("requestedEnd"))), center);
            setCell(excelRow, 9, formatTime(str(row.get("requestedAfternoonStart"))), center);
            setCell(excelRow, 10, formatTime(str(row.get("requestedAfternoonEnd"))), center);
            setCell(excelRow, 11, formLabel(row), center);
            if (isInsideShift(row)) {
                // Trong ca tính theo công, không có giờ quy đổi.
                setNumberCell(excelRow, 12, toDouble(row.get("deploymentWorkUnits")),
                        s.numeric(fill, FMT_WORK_UNITS));
                setCell(excelRow, 13, "", center);
            } else {
                setNumberCell(excelRow, 12, toDouble(row.get("deploymentActualHours")),
                        s.numeric(fill, FMT_HOURS));
                setNumberCell(excelRow, 13, toDouble(row.get("deploymentCreditedHours")),
                        s.numeric(fill, FMT_HOURS));
            }
            setCell(excelRow, 14, str(row.get("reason")), text);
            setCell(excelRow, 15, statusLabel(status), center);
            setCell(excelRow, 16, formatDateTime(str(row.get("createdAt"))), center);
            idx++;
        }

        if (rows.isEmpty()) {
            Row empty = sheet.createRow(r++);
            empty.setHeightInPoints(20f);
            Cell cell = empty.createCell(0);
            cell.setCellValue("Không có đơn điều động trong khoảng thời gian đã chọn.");
            cell.setCellStyle(s.meta);
            sheet.addMergedRegion(new CellRangeAddress(r - 1, r - 1, 0, lastCol));
        }

        r++;
        Row foot = sheet.createRow(r);
        foot.setHeightInPoints(16f);
        Cell footCell = foot.createCell(0);
        footCell.setCellValue("Ghi chú: Hình thức «Trong ca» tính theo công (cột «Tổng giờ điều động» ghi số công, "
                + "không có giờ quy đổi); «Ngoài ca» tính giờ thực tế × hệ số điều động.");
        footCell.setCellStyle(s.footnote);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));

        sheet.createFreezePane(0, headerRowIdx + 1);
        sheet.setAutoFilter(new CellRangeAddress(headerRowIdx, Math.max(headerRowIdx, r - 2), 0, lastCol));

        int[] widths = {
                6, 12, 22, 18, 22, 24, 14, 12, 12, 14, 14, 12, 18, 18, 36, 28, 16
        };
        for (int c = 0; c < widths.length; c++) {
            sheet.setColumnWidth(c, widths[c] * 256);
        }
    }

    private static String formLabel(Map<String, Object> row) {
        Object inside = row.get("deploymentInsideShift");
        if (inside instanceof Boolean b) {
            return b ? "Trong ca" : "Ngoài ca";
        }
        return "";
    }

    private static boolean isInsideShift(Map<String, Object> row) {
        return row.get("deploymentInsideShift") instanceof Boolean b && b;
    }

    private static Double toDouble(Object v) {
        if (v instanceof Number n) {
            return n.doubleValue();
        }
        if (v instanceof String str && !str.isBlank()) {
            try {
                return Double.valueOf(str.trim());
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private static String statusLabel(String status) {
        if (status == null || status.isBlank()) return "";
        return switch (status) {
            case "PENDING_HEAD" -> "Chờ lãnh đạo";
            case "HEAD_REJECTED" -> "Lãnh đạo từ chối";
            case "PENDING_NURSING_HEAD" -> "Chờ Trưởng phòng Điều dưỡng";
            case "NURSING_HEAD_REJECTED" -> "Trưởng phòng Điều dưỡng từ chối";
            case "PENDING_HR" -> "Chờ HCNS";
            case "HR_REJECTED" -> "HCNS từ chối";
            case "PENDING_DIRECTOR" -> "Chờ Giám đốc";
            case "DIRECTOR_REJECTED" -> "Giám đốc từ chối";
            case "APPROVED", "APPROVED_NO_FINE" -> "Đã duyệt";
            case "WITHDRAWN" -> "Đã thu hồi";
            default -> status;
        };
    }

    private static CellStyle statusStyle(Styles s, String status, boolean zebra, boolean center) {
        if (status != null) {
            if (status.equals("APPROVED") || status.equals("APPROVED_NO_FINE")) {
                return center ? s.centerApproved : s.textApproved;
            }
            if (status.endsWith("_REJECTED")) {
                return center ? s.centerRejected : s.textRejected;
            }
            if (status.startsWith("PENDING_")) {
                return center ? s.centerPending : s.textPending;
            }
        }
        if (zebra) {
            return center ? s.centerZebra : s.textZebra;
        }
        return center ? s.center : s.text;
    }

    /** Nền của dòng theo trạng thái — dùng lại cho ô số (null = không tô). */
    private static String statusFill(String status, boolean zebra) {
        if (status != null) {
            if (status.equals("APPROVED") || status.equals("APPROVED_NO_FINE")) {
                return APPROVED_FILL;
            }
            if (status.endsWith("_REJECTED")) {
                return REJECTED_FILL;
            }
            if (status.startsWith("PENDING_")) {
                return PENDING_FILL;
            }
        }
        return zebra ? ZEBRA : null;
    }

    private static String formatDate(String iso) {
        if (iso == null || iso.isBlank()) return "";
        try {
            return LocalDate.parse(iso.length() >= 10 ? iso.substring(0, 10) : iso).format(DATE_VN);
        } catch (Exception ex) {
            return iso;
        }
    }

    private static String formatDateTime(String iso) {
        if (iso == null || iso.isBlank()) return "";
        try {
            if (iso.length() >= 10) {
                return LocalDate.parse(iso.substring(0, 10)).format(DATE_VN);
            }
        } catch (Exception ignored) {
            // fall through
        }
        return iso;
    }

    private static String formatTime(String raw) {
        if (raw == null || raw.isBlank()) return "";
        String t = raw.trim();
        if (t.length() >= 5) {
            return t.substring(0, 5);
        }
        return t;
    }

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

    /** Ghi ô số; giá trị null để trống ô (SUM bỏ qua). */
    private static void setNumberCell(Row row, int col, Double value, CellStyle style) {
        Cell cell = row.createCell(col);
        if (value != null) {
            cell.setCellValue(value);
        }
        cell.setCellStyle(style);
    }

    private static void setCell(Row row, int col, long value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(value);
        cell.setCellStyle(style);
    }

    private static String str(Object v) {
        return v != null ? String.valueOf(v) : "";
    }

    private static YearMonthRange resolveRange(LocalDate fromDate, LocalDate toDate) {
        java.time.YearMonth ym = java.time.YearMonth.now();
        LocalDate from = fromDate != null ? fromDate : ym.atDay(1);
        LocalDate to = toDate != null ? toDate : ym.atEndOfMonth();
        return new YearMonthRange(from, to);
    }

    private record YearMonthRange(LocalDate from, LocalDate to) {}

    private static final class Styles {
        final CellStyle title;
        final CellStyle subtitle;
        final CellStyle meta;
        final CellStyle footnote;
        final CellStyle header;
        final CellStyle text;
        final CellStyle center;
        final CellStyle textZebra;
        final CellStyle centerZebra;
        final CellStyle textApproved;
        final CellStyle centerApproved;
        final CellStyle textRejected;
        final CellStyle centerRejected;
        final CellStyle textPending;
        final CellStyle centerPending;

        private final XSSFWorkbook wb;
        /** Ô số: mỗi cặp (nền, định dạng) chỉ tạo một style — Excel giới hạn số style. */
        private final Map<String, CellStyle> numericStyles = new HashMap<>();

        Styles(XSSFWorkbook wb) {
            this.wb = wb;
            title = plain(wb, 16, true, BRAND, HorizontalAlignment.CENTER);
            subtitle = plain(wb, 13, true, "134E4A", HorizontalAlignment.CENTER);
            meta = plain(wb, 10, false, "64748B", HorizontalAlignment.CENTER);
            footnote = plain(wb, 9, false, "64748B", HorizontalAlignment.LEFT);

            header = data(wb, 11, true, HEADER_TEXT, BRAND, HorizontalAlignment.CENTER);
            header.setWrapText(true);

            text = data(wb, 11, false, "0F172A", null, HorizontalAlignment.LEFT);
            center = data(wb, 11, false, "0F172A", null, HorizontalAlignment.CENTER);
            textZebra = data(wb, 11, false, "0F172A", ZEBRA, HorizontalAlignment.LEFT);
            centerZebra = data(wb, 11, false, "0F172A", ZEBRA, HorizontalAlignment.CENTER);

            textApproved = data(wb, 11, false, "0F172A", APPROVED_FILL, HorizontalAlignment.LEFT);
            centerApproved = data(wb, 11, false, "0F172A", APPROVED_FILL, HorizontalAlignment.CENTER);
            textRejected = data(wb, 11, false, "0F172A", REJECTED_FILL, HorizontalAlignment.LEFT);
            centerRejected = data(wb, 11, false, "0F172A", REJECTED_FILL, HorizontalAlignment.CENTER);
            textPending = data(wb, 11, false, "0F172A", PENDING_FILL, HorizontalAlignment.LEFT);
            centerPending = data(wb, 11, false, "0F172A", PENDING_FILL, HorizontalAlignment.CENTER);
        }

        CellStyle numeric(String fillHex, String format) {
            return numericStyles.computeIfAbsent((fillHex != null ? fillHex : "-") + "|" + format, key -> {
                XSSFCellStyle style = data(wb, 11, false, "0F172A", fillHex, HorizontalAlignment.CENTER);
                style.setDataFormat(wb.createDataFormat().getFormat(format));
                return style;
            });
        }

        private static XSSFCellStyle plain(
                XSSFWorkbook wb, int size, boolean bold, String fontHex, HorizontalAlignment align) {
            XSSFCellStyle style = fontOnly(wb, size, bold, fontHex);
            style.setAlignment(align);
            style.setVerticalAlignment(VerticalAlignment.CENTER);
            return style;
        }

        private static XSSFCellStyle data(
                XSSFWorkbook wb, int size, boolean bold, String fontHex, String fillHex, HorizontalAlignment align) {
            XSSFCellStyle style = fontOnly(wb, size, bold, fontHex);
            style.setAlignment(align);
            style.setVerticalAlignment(VerticalAlignment.CENTER);
            style.setBorderTop(BorderStyle.THIN);
            style.setBorderBottom(BorderStyle.THIN);
            style.setBorderLeft(BorderStyle.THIN);
            style.setBorderRight(BorderStyle.THIN);
            style.setTopBorderColor(IndexedColors.GREY_25_PERCENT.getIndex());
            style.setBottomBorderColor(IndexedColors.GREY_25_PERCENT.getIndex());
            style.setLeftBorderColor(IndexedColors.GREY_25_PERCENT.getIndex());
            style.setRightBorderColor(IndexedColors.GREY_25_PERCENT.getIndex());
            if (fillHex != null) {
                style.setFillForegroundColor(hexColor(fillHex));
                style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            }
            return style;
        }

        private static XSSFCellStyle fontOnly(XSSFWorkbook wb, int size, boolean bold, String fontHex) {
            XSSFFont font = wb.createFont();
            font.setFontName(FONT_NAME);
            font.setFontHeightInPoints((short) size);
            font.setBold(bold);
            font.setColor(hexColor(fontHex));
            XSSFCellStyle style = wb.createCellStyle();
            style.setFont(font);
            return style;
        }

        private static XSSFColor hexColor(String hex) {
            byte[] rgb = new byte[3];
            rgb[0] = (byte) Integer.parseInt(hex.substring(0, 2), 16);
            rgb[1] = (byte) Integer.parseInt(hex.substring(2, 4), 16);
            rgb[2] = (byte) Integer.parseInt(hex.substring(4, 6), 16);
            return new XSSFColor(rgb, null);
        }
    }
}
