package com.minhan.hrm.service;

import com.minhan.hrm.exception.ApiException;
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

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Xuất Excel thống kê xếp loại tháng khối Điều dưỡng — chỉ phiếu Trưởng phòng ĐD đã duyệt.
 * Bố cục theo mẫu: Họ tên · Khoa/Phòng · Điểm tiêu chí (I…VII) · Tổng điểm (+ STT, Xếp loại).
 */
@Service
@RequiredArgsConstructor
public class NursingEvaluationExcelService {

    private static final String FONT_NAME = "Times New Roman";
    private static final String BRAND = "0F766E";
    private static final String BRAND_DARK = "134E4A";
    private static final String SUB_HEADER = "CCE7E3";
    private static final String ZEBRA = "F1F5F9";
    private static final String AVERAGE_FILL = "E2EFED";
    private static final String INK = "0F172A";
    private static final String MUTED = "64748B";
    /** Màu xếp loại theo thứ hạng (cao → thấp); mức thấp nhất luôn đỏ. */
    private static final String[] GRADE_FILLS = {"DCFCE7", "CCFBF1", "FEF3C7", "FFEDD5", "E0E7FF"};
    private static final String LOWEST_GRADE_FILL = "FEE2E2";
    /** General: 15 · 12.5 · -5 (định dạng "0.##" hiện dấu chấm thừa "15."). */
    private static final String NUMBER_FORMAT = "General";

    private static final DateTimeFormatter DATE_VN = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final int FIXED_LEFT = 3; // STT, Họ tên, Khoa/Phòng

    private final NursingEvaluationService nursingEvaluationService;

    public byte[] buildMonthlyRanking(int year, int month, String templateCode) {
        NursingEvaluationService.MonthlyRanking data =
                nursingEvaluationService.monthlyRankingForExport(year, month, templateCode);
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Styles s = new Styles(wb);
            writeSheet(wb, s, data, year, month);
            wb.write(out);
            return out.toByteArray();
        } catch (ApiException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file Excel: " + ex.getMessage());
        }
    }

    private void writeSheet(
            XSSFWorkbook wb, Styles s, NursingEvaluationService.MonthlyRanking data, int year, int month) {
        Sheet sheet = wb.createSheet(String.format("Xếp loại T%d-%d", month, year));
        sheet.setDisplayGridlines(false);
        List<NursingEvaluationService.RankingSection> sections = data.sections();
        int firstSection = FIXED_LEFT;
        int totalCol = firstSection + sections.size();
        int gradeCol = totalCol + 1;
        int lastCol = gradeCol;
        Map<String, String> gradeFills = gradeFills(data);

        int r = 0;
        r = banner(sheet, s.title, r, lastCol, "BỆNH VIỆN MINH AN", 28f);
        r = banner(sheet, s.subtitle, r, lastCol,
                String.format("BẢNG TỔNG HỢP ĐÁNH GIÁ, XẾP LOẠI NHÂN VIÊN KHỐI ĐIỀU DƯỠNG — THÁNG %d/%d", month, year),
                22f);
        r = banner(sheet, s.meta, r, lastCol,
                (data.templateName().isBlank() ? "" : "Mẫu: " + data.templateName() + "     •     ")
                        + "Tổng số: " + data.rows().size() + " nhân viên"
                        + "     •     Phiếu đã được Trưởng phòng Điều dưỡng duyệt"
                        + "     •     Xuất ngày: " + LocalDate.now().format(DATE_VN),
                18f);
        r++;

        // ---------------------------------------------------------------- tiêu đề 2 tầng
        int head1 = r++;
        int head2 = r++;
        Row h1 = sheet.createRow(head1);
        Row h2 = sheet.createRow(head2);
        h1.setHeightInPoints(24f);
        h2.setHeightInPoints(48f);
        for (int c = 0; c <= lastCol; c++) {
            h1.createCell(c).setCellStyle(s.header);
            h2.createCell(c).setCellStyle(c >= firstSection && c < totalCol ? s.subHeader : s.header);
        }
        headerSpan(sheet, h1, head1, head2, 0, "STT");
        headerSpan(sheet, h1, head1, head2, 1, "Họ tên");
        headerSpan(sheet, h1, head1, head2, 2, "Khoa / Phòng");
        if (!sections.isEmpty()) {
            h1.getCell(firstSection).setCellValue("Điểm tiêu chí");
            if (sections.size() > 1) {
                sheet.addMergedRegion(new CellRangeAddress(head1, head1, firstSection, totalCol - 1));
            }
            for (int i = 0; i < sections.size(); i++) {
                h2.getCell(firstSection + i).setCellValue(sectionLabel(sections.get(i)));
            }
        }
        headerSpan(sheet, h1, head1, head2, totalCol, "Tổng điểm");
        headerSpan(sheet, h1, head1, head2, gradeCol, "Xếp loại");

        // ---------------------------------------------------------------- dữ liệu
        int idx = 1;
        Map<String, BigDecimal> sectionSums = new LinkedHashMap<>();
        BigDecimal totalSum = BigDecimal.ZERO;
        int scored = 0;
        for (NursingEvaluationService.RankingRow row : data.rows()) {
            boolean zebra = idx % 2 == 0;
            Row x = sheet.createRow(r++);
            x.setHeightInPoints(20f);
            cell(x, 0, idx, zebra ? s.centerZebra : s.center);
            cell(x, 1, row.fullName(), zebra ? s.nameZebra : s.name);
            cell(x, 2, row.departmentName(), zebra ? s.textZebra : s.text);
            for (int i = 0; i < sections.size(); i++) {
                String name = sections.get(i).name();
                BigDecimal v = row.sectionPoints().get(name);
                numberCell(x, firstSection + i, v, zebra ? s.numberZebra : s.number);
                if (v != null) {
                    sectionSums.merge(name, v, BigDecimal::add);
                }
            }
            numberCell(x, totalCol, row.totalScore(), zebra ? s.totalZebra : s.total);
            if (row.totalScore() != null) {
                totalSum = totalSum.add(row.totalScore());
                scored++;
            }
            String grade = row.grade() != null ? row.grade() : "";
            cell(x, gradeCol, grade, s.grade(gradeFills.getOrDefault(grade, zebra ? ZEBRA : null)));
            idx++;
        }

        if (data.rows().isEmpty()) {
            Row empty = sheet.createRow(r++);
            empty.setHeightInPoints(22f);
            for (int c = 0; c <= lastCol; c++) {
                empty.createCell(c).setCellStyle(s.center);
            }
            empty.getCell(0).setCellValue(
                    "Chưa có phiếu đánh giá nào được Trưởng phòng Điều dưỡng duyệt trong tháng này.");
            sheet.addMergedRegion(new CellRangeAddress(r - 1, r - 1, 0, lastCol));
        } else {
            // Dòng điểm trung bình
            Row avg = sheet.createRow(r++);
            avg.setHeightInPoints(22f);
            int n = data.rows().size();
            for (int c = 0; c <= lastCol; c++) {
                avg.createCell(c).setCellStyle(s.averageLabel);
            }
            avg.getCell(0).setCellValue("Điểm trung bình");
            sheet.addMergedRegion(new CellRangeAddress(r - 1, r - 1, 0, FIXED_LEFT - 1));
            for (int i = 0; i < sections.size(); i++) {
                BigDecimal sum = sectionSums.get(sections.get(i).name());
                numberCell(avg, firstSection + i,
                        sum == null ? null : sum.divide(BigDecimal.valueOf(n), 2, RoundingMode.HALF_UP),
                        s.averageNumber);
            }
            numberCell(avg, totalCol,
                    scored == 0 ? null : totalSum.divide(BigDecimal.valueOf(scored), 2, RoundingMode.HALF_UP),
                    s.averageNumber);
        }

        // ---------------------------------------------------------------- thống kê xếp loại
        r++;
        r = gradeSummary(sheet, s, r, data, gradeFills);

        r++;
        Row foot = sheet.createRow(r);
        Cell footCell = foot.createCell(0);
        footCell.setCellValue("Ghi chú: Chỉ gồm phiếu đã được Trưởng phòng Điều dưỡng duyệt (đang chờ HCNS, chờ Giám đốc "
                + "hoặc đã duyệt). Điểm trừ ghi số âm. Xếp loại theo tỷ lệ tổng điểm trên điểm chuẩn của mẫu.");
        footCell.setCellStyle(s.footnote);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));

        // ---------------------------------------------------------------- khung trang
        sheet.createFreezePane(FIXED_LEFT, head2 + 1);
        sheet.setColumnWidth(0, 6 * 256);
        sheet.setColumnWidth(1, 26 * 256);
        sheet.setColumnWidth(2, 30 * 256);
        for (int i = 0; i < sections.size(); i++) {
            sheet.setColumnWidth(firstSection + i, 17 * 256);
        }
        sheet.setColumnWidth(totalCol, 12 * 256);
        sheet.setColumnWidth(gradeCol, 14 * 256);

        PrintSetup print = sheet.getPrintSetup();
        print.setLandscape(true);
        print.setPaperSize(PrintSetup.A4_PAPERSIZE);
        sheet.setFitToPage(true);
        print.setFitWidth((short) 1);
        print.setFitHeight((short) 0);
        sheet.setHorizontallyCenter(true);
        sheet.setRepeatingRows(new CellRangeAddress(head1, head2, -1, -1));
    }

    /** Bảng nhỏ: số người / tỷ lệ theo từng mức xếp loại. */
    private int gradeSummary(
            Sheet sheet, Styles s, int r, NursingEvaluationService.MonthlyRanking data, Map<String, String> fills) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        for (NursingEvaluationTemplateService.GradeBand band : data.gradingScale()) {
            counts.put(band.label(), 0);
        }
        for (NursingEvaluationService.RankingRow row : data.rows()) {
            String g = row.grade() != null && !row.grade().isBlank() ? row.grade() : "Chưa xếp loại";
            counts.merge(g, 1, Integer::sum);
        }
        int total = data.rows().size();

        Row title = sheet.createRow(r++);
        title.setHeightInPoints(20f);
        String[] heads = {"Thống kê xếp loại", "", "Số người", "Tỷ lệ"};
        for (int c = 0; c < heads.length; c++) {
            Cell cell = title.createCell(c);
            cell.setCellValue(heads[c]);
            cell.setCellStyle(s.header);
        }
        sheet.addMergedRegion(new CellRangeAddress(r - 1, r - 1, 0, 1));

        for (Map.Entry<String, Integer> e : counts.entrySet()) {
            Row row = sheet.createRow(r++);
            row.setHeightInPoints(18f);
            CellStyle label = s.grade(fills.get(e.getKey()));
            for (int c = 0; c < 2; c++) {
                row.createCell(c).setCellStyle(label);
            }
            row.getCell(0).setCellValue(e.getKey());
            sheet.addMergedRegion(new CellRangeAddress(r - 1, r - 1, 0, 1));
            cell(row, 2, e.getValue(), s.center);
            Cell pct = row.createCell(3);
            pct.setCellValue(total == 0 ? 0 : e.getValue() / (double) total);
            pct.setCellStyle(s.percent);
        }
        return r;
    }

    private static Map<String, String> gradeFills(NursingEvaluationService.MonthlyRanking data) {
        Map<String, String> out = new HashMap<>();
        List<NursingEvaluationTemplateService.GradeBand> scale = data.gradingScale();
        for (int i = 0; i < scale.size(); i++) {
            boolean lowest = i == scale.size() - 1 && scale.size() > 1;
            out.put(scale.get(i).label(), lowest ? LOWEST_GRADE_FILL : GRADE_FILLS[i % GRADE_FILLS.length]);
        }
        return out;
    }

    private static String sectionLabel(NursingEvaluationService.RankingSection section) {
        String name = section.name();
        if (section.maxPoints() != null && section.maxPoints().compareTo(BigDecimal.ZERO) > 0) {
            return name + "\n(" + section.maxPoints().stripTrailingZeros().toPlainString() + " điểm)";
        }
        if (section.bonus()) {
            return name + "\n(cộng thêm)";
        }
        if (section.penalty()) {
            return name + "\n(trừ)";
        }
        return name;
    }

    private static void headerSpan(Sheet sheet, Row h1, int head1, int head2, int col, String text) {
        h1.getCell(col).setCellValue(text);
        sheet.addMergedRegion(new CellRangeAddress(head1, head2, col, col));
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

    private static void cell(Row row, int col, String value, CellStyle style) {
        Cell c = row.createCell(col);
        c.setCellValue(value != null ? value : "");
        c.setCellStyle(style);
    }

    private static void cell(Row row, int col, long value, CellStyle style) {
        Cell c = row.createCell(col);
        c.setCellValue(value);
        c.setCellStyle(style);
    }

    /** Ô số thực (SUM/lọc được); null để trống. */
    private static void numberCell(Row row, int col, BigDecimal value, CellStyle style) {
        Cell c = row.createCell(col);
        if (value != null) {
            c.setCellValue(value.doubleValue());
        }
        c.setCellStyle(style);
    }

    private static final class Styles {
        final CellStyle title;
        final CellStyle subtitle;
        final CellStyle meta;
        final CellStyle footnote;
        final CellStyle header;
        final CellStyle subHeader;
        final CellStyle text;
        final CellStyle textZebra;
        final CellStyle name;
        final CellStyle nameZebra;
        final CellStyle center;
        final CellStyle centerZebra;
        final CellStyle number;
        final CellStyle numberZebra;
        final CellStyle total;
        final CellStyle totalZebra;
        final CellStyle averageLabel;
        final CellStyle averageNumber;
        final CellStyle percent;

        private final XSSFWorkbook wb;
        private final Map<String, CellStyle> gradeStyles = new HashMap<>();

        Styles(XSSFWorkbook wb) {
            this.wb = wb;
            title = plain(16, true, BRAND, HorizontalAlignment.CENTER);
            subtitle = plain(13, true, BRAND_DARK, HorizontalAlignment.CENTER);
            meta = plain(10, false, MUTED, HorizontalAlignment.CENTER);
            footnote = plain(9, false, MUTED, HorizontalAlignment.LEFT);

            header = data(11, true, "FFFFFF", BRAND, HorizontalAlignment.CENTER);
            header.setWrapText(true);
            subHeader = data(10, true, BRAND_DARK, SUB_HEADER, HorizontalAlignment.CENTER);
            subHeader.setWrapText(true);

            text = data(11, false, INK, null, HorizontalAlignment.LEFT);
            textZebra = data(11, false, INK, ZEBRA, HorizontalAlignment.LEFT);
            name = data(11, true, INK, null, HorizontalAlignment.LEFT);
            nameZebra = data(11, true, INK, ZEBRA, HorizontalAlignment.LEFT);
            center = data(11, false, INK, null, HorizontalAlignment.CENTER);
            centerZebra = data(11, false, INK, ZEBRA, HorizontalAlignment.CENTER);
            number = numeric(data(11, false, INK, null, HorizontalAlignment.CENTER));
            numberZebra = numeric(data(11, false, INK, ZEBRA, HorizontalAlignment.CENTER));
            total = numeric(data(11, true, BRAND_DARK, null, HorizontalAlignment.CENTER));
            totalZebra = numeric(data(11, true, BRAND_DARK, ZEBRA, HorizontalAlignment.CENTER));
            averageLabel = data(11, true, BRAND_DARK, AVERAGE_FILL, HorizontalAlignment.CENTER);
            averageNumber = numeric(data(11, true, BRAND_DARK, AVERAGE_FILL, HorizontalAlignment.CENTER));
            percent = data(11, false, INK, null, HorizontalAlignment.CENTER);
            percent.setDataFormat(wb.createDataFormat().getFormat("0.0%"));
        }

        /** Ô xếp loại — mỗi màu nền một style (Excel giới hạn số style). */
        CellStyle grade(String fillHex) {
            return gradeStyles.computeIfAbsent(fillHex != null ? fillHex : "-",
                    key -> data(11, true, INK, fillHex, HorizontalAlignment.CENTER));
        }

        private XSSFCellStyle numeric(XSSFCellStyle style) {
            style.setDataFormat(wb.createDataFormat().getFormat(NUMBER_FORMAT));
            return style;
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
