package com.minhan.hrm.service;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.PrintSetup;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.VerticalAlignment;
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
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.stream.Collectors;

/**
 * Xuất Excel danh sách cán bộ, nhân viên có sinh nhật trong các tháng đã chọn
 * (toàn viện: chính thức, thử việc, thực tập, nghỉ phép tạm — trừ đã nghỉ việc).
 */
@Service
@RequiredArgsConstructor
public class BirthdayExcelExportService {

    private static final String FONT_NAME = "Times New Roman";
    private static final String BRAND = "0F766E";
    private static final String BRAND_DARK = "134E4A";
    private static final String MONTH_BAND = "CCE7E3";
    private static final String ZEBRA = "F1F5F9";
    private static final String MILESTONE = "FEF3C7";
    private static final String INK = "0F172A";
    private static final String MUTED = "64748B";

    private static final DateTimeFormatter DATE_VN = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter DAY_MONTH = DateTimeFormatter.ofPattern("dd/MM");

    private static final String[] HEADERS = {
            "STT", "Họ và tên", "Mã NV", "Giới tính", "Ngày sinh", "Sinh nhật",
            "Tuổi", "Chức danh", "Khoa / Phòng", "Tình trạng", "Số điện thoại"
    };
    private static final int[] WIDTHS = {6, 28, 13, 10, 13, 11, 8, 24, 32, 14, 15};

    private final EmployeeRepository employeeRepository;

    @Transactional(readOnly = true)
    public byte[] export(Collection<Integer> months) {
        TreeSet<Integer> selected = months == null ? new TreeSet<>() : months.stream()
                .filter(m -> m != null && m >= 1 && m <= 12)
                .collect(Collectors.toCollection(TreeSet::new));
        if (selected.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chọn ít nhất một tháng để xuất danh sách sinh nhật");
        }
        int year = LocalDate.now().getYear();

        Map<Integer, List<Employee>> byMonth = new TreeMap<>();
        selected.forEach(m -> byMonth.put(m, new ArrayList<>()));
        int missingDob = 0;
        for (Employee e : employeeRepository.findAllWithDepartment()) {
            if (e.getStatus() == EmployeeStatus.TERMINATED) {
                continue;
            }
            if (e.getDateOfBirth() == null) {
                missingDob++;
                continue;
            }
            List<Employee> bucket = byMonth.get(e.getDateOfBirth().getMonthValue());
            if (bucket != null) {
                bucket.add(e);
            }
        }
        Comparator<Employee> byDayThenName = Comparator
                .comparing((Employee e) -> e.getDateOfBirth().getDayOfMonth())
                .thenComparing(Employee::getFullName, String.CASE_INSENSITIVE_ORDER);
        byMonth.values().forEach(list -> list.sort(byDayThenName));

        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Styles s = new Styles(wb);
            writeSheet(wb, s, byMonth, year, missingDob);
            wb.write(out);
            return out.toByteArray();
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file Excel: " + ex.getMessage());
        }
    }

    /** Tên file: SINH-NHAT-T9-T10-2026.xlsx */
    public static String filename(Collection<Integer> months) {
        String part = months.stream().filter(m -> m != null && m >= 1 && m <= 12)
                .distinct().sorted().map(m -> "T" + m).collect(Collectors.joining("-"));
        return "SINH-NHAT-" + part + "-" + LocalDate.now().getYear() + ".xlsx";
    }

    private void writeSheet(
            XSSFWorkbook wb, Styles s, Map<Integer, List<Employee>> byMonth, int year, int missingDob) {
        Sheet sheet = wb.createSheet("Sinh nhật");
        sheet.setDisplayGridlines(false);
        int lastCol = HEADERS.length - 1;
        int total = byMonth.values().stream().mapToInt(List::size).sum();
        String monthsLabel = byMonth.keySet().stream().map(String::valueOf).collect(Collectors.joining(", "));

        int r = 0;
        r = banner(sheet, s.title, r, lastCol, "BỆNH VIỆN MINH AN", 28f);
        r = banner(sheet, s.subtitle, r, lastCol,
                "DANH SÁCH CÁN BỘ, NHÂN VIÊN CÓ SINH NHẬT THÁNG " + monthsLabel + "/" + year, 22f);
        r = banner(sheet, s.meta, r, lastCol,
                "Tổng số: " + total + " người     •     Gồm nhân viên chính thức, thử việc, thực tập"
                        + "     •     Xuất ngày: " + LocalDate.now().format(DATE_VN),
                18f);
        r++;

        int headerRow = r;
        Row header = sheet.createRow(r++);
        header.setHeightInPoints(24f);
        for (int c = 0; c < HEADERS.length; c++) {
            Cell cell = header.createCell(c);
            cell.setCellValue(c == 6 ? "Tuổi (" + year + ")" : HEADERS[c]);
            cell.setCellStyle(s.header);
        }

        for (Map.Entry<Integer, List<Employee>> entry : byMonth.entrySet()) {
            int month = entry.getKey();
            List<Employee> list = entry.getValue();

            Row band = sheet.createRow(r++);
            band.setHeightInPoints(22f);
            for (int c = 0; c <= lastCol; c++) {
                band.createCell(c).setCellStyle(s.band);
            }
            band.getCell(0).setCellValue("THÁNG " + month + "  ·  " + list.size() + " người");
            sheet.addMergedRegion(new CellRangeAddress(r - 1, r - 1, 0, lastCol));

            if (list.isEmpty()) {
                Row empty = sheet.createRow(r++);
                empty.setHeightInPoints(20f);
                for (int c = 0; c <= lastCol; c++) {
                    empty.createCell(c).setCellStyle(s.center);
                }
                empty.getCell(0).setCellValue("Không có nhân viên sinh trong tháng " + month + ".");
                sheet.addMergedRegion(new CellRangeAddress(r - 1, r - 1, 0, lastCol));
                continue;
            }

            int idx = 1;
            for (Employee e : list) {
                boolean zebra = idx % 2 == 0;
                LocalDate dob = e.getDateOfBirth();
                int age = year - dob.getYear();
                boolean milestone = age > 0 && age % 10 == 0;
                Row row = sheet.createRow(r++);
                row.setHeightInPoints(19f);
                CellStyle text = zebra ? s.textZebra : s.text;
                CellStyle center = zebra ? s.centerZebra : s.center;
                number(row, 0, idx, center);
                text(row, 1, e.getFullName(), zebra ? s.nameZebra : s.name);
                text(row, 2, e.getEmployeeCode(), center);
                text(row, 3, genderLabel(e.getGender()), center);
                text(row, 4, dob.format(DATE_VN), center);
                text(row, 5, dob.format(DAY_MONTH), zebra ? s.birthdayZebra : s.birthday);
                // Tuổi tròn chục (30, 40, 50…) tô vàng — dịp chúc mừng đặc biệt.
                number(row, 6, age, milestone ? s.milestone : center);
                text(row, 7, e.getPosition() != null ? e.getPosition().getTitle() : "", text);
                text(row, 8, e.getDepartment() != null ? e.getDepartment().getName() : "", text);
                text(row, 9, statusLabel(e.getStatus()), center);
                text(row, 10, e.getPhone(), center);
                idx++;
            }
        }

        r++;
        Row foot = sheet.createRow(r++);
        Cell f1 = foot.createCell(0);
        f1.setCellValue("Ghi chú: Ô tuổi tô vàng là năm tròn tuổi (30, 40, 50…). Sắp xếp theo ngày sinh nhật trong tháng."
                + (missingDob > 0
                        ? " Có " + missingDob + " nhân sự chưa nhập ngày sinh trong hồ sơ — không có trong danh sách."
                        : ""));
        f1.setCellStyle(s.footnote);
        sheet.addMergedRegion(new CellRangeAddress(r - 1, r - 1, 0, lastCol));

        sheet.createFreezePane(2, headerRow + 1);
        for (int c = 0; c < WIDTHS.length; c++) {
            sheet.setColumnWidth(c, WIDTHS[c] * 256);
        }
        PrintSetup print = sheet.getPrintSetup();
        print.setLandscape(true);
        print.setPaperSize(PrintSetup.A4_PAPERSIZE);
        sheet.setFitToPage(true);
        print.setFitWidth((short) 1);
        print.setFitHeight((short) 0);
        sheet.setHorizontallyCenter(true);
        sheet.setRepeatingRows(new CellRangeAddress(headerRow, headerRow, -1, -1));
    }

    private static String genderLabel(String g) {
        if (g == null) {
            return "";
        }
        return switch (g.trim().toUpperCase()) {
            case "MALE", "M", "NAM" -> "Nam";
            case "FEMALE", "F", "NỮ", "NU" -> "Nữ";
            default -> g.trim();
        };
    }

    private static String statusLabel(EmployeeStatus status) {
        if (status == null) {
            return "";
        }
        return switch (status) {
            case ACTIVE -> "Chính thức";
            case PROBATION -> "Thử việc";
            case INTERN -> "Thực tập";
            case ON_LEAVE -> "Nghỉ phép tạm";
            case TERMINATED -> "Đã nghỉ việc";
        };
    }

    private static int banner(Sheet sheet, CellStyle style, int r, int lastCol, String text, float height) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(height);
        Cell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(style);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    private static void text(Row row, int col, String value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(value != null ? value : "");
        cell.setCellStyle(style);
    }

    private static void number(Row row, int col, long value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(value);
        cell.setCellStyle(style);
    }

    private static final class Styles {
        final CellStyle title;
        final CellStyle subtitle;
        final CellStyle meta;
        final CellStyle footnote;
        final CellStyle header;
        final CellStyle band;
        final CellStyle text;
        final CellStyle textZebra;
        final CellStyle name;
        final CellStyle nameZebra;
        final CellStyle center;
        final CellStyle centerZebra;
        final CellStyle birthday;
        final CellStyle birthdayZebra;
        final CellStyle milestone;

        private final XSSFWorkbook wb;

        Styles(XSSFWorkbook wb) {
            this.wb = wb;
            title = plain(16, true, BRAND, HorizontalAlignment.CENTER);
            subtitle = plain(13, true, BRAND_DARK, HorizontalAlignment.CENTER);
            meta = plain(10, false, MUTED, HorizontalAlignment.CENTER);
            footnote = plain(9, false, MUTED, HorizontalAlignment.LEFT);
            header = data(11, true, "FFFFFF", BRAND, HorizontalAlignment.CENTER);
            header.setWrapText(true);
            band = data(11, true, BRAND_DARK, MONTH_BAND, HorizontalAlignment.LEFT);
            text = data(11, false, INK, null, HorizontalAlignment.LEFT);
            textZebra = data(11, false, INK, ZEBRA, HorizontalAlignment.LEFT);
            name = data(11, true, INK, null, HorizontalAlignment.LEFT);
            nameZebra = data(11, true, INK, ZEBRA, HorizontalAlignment.LEFT);
            center = data(11, false, INK, null, HorizontalAlignment.CENTER);
            centerZebra = data(11, false, INK, ZEBRA, HorizontalAlignment.CENTER);
            birthday = data(11, true, BRAND, null, HorizontalAlignment.CENTER);
            birthdayZebra = data(11, true, BRAND, ZEBRA, HorizontalAlignment.CENTER);
            milestone = data(11, true, "92400E", MILESTONE, HorizontalAlignment.CENTER);
        }

        private XSSFCellStyle plain(int size, boolean bold, String fontHex, HorizontalAlignment align) {
            XSSFCellStyle style = fontOnly(size, bold, fontHex);
            style.setAlignment(align);
            style.setVerticalAlignment(VerticalAlignment.CENTER);
            return style;
        }

        private XSSFCellStyle data(int size, boolean bold, String fontHex, String fillHex, HorizontalAlignment align) {
            XSSFCellStyle style = fontOnly(size, bold, fontHex);
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

        private XSSFCellStyle fontOnly(int size, boolean bold, String fontHex) {
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
