package com.minhan.hrm.service;

import com.lowagie.text.*;
import com.lowagie.text.pdf.*;
import com.minhan.hrm.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class QtktComplianceReportPdfService {

    private static final String FONT_REGULAR = "Times New Roman";
    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final Color BRAND = new Color(15, 76, 92);
    private static final Color BRAND_LIGHT = new Color(224, 242, 246);
    private static final Color INK = new Color(28, 28, 28);
    private static final Color MUTED = new Color(82, 82, 82);
    private static final Color BORDER = new Color(180, 180, 180);
    private static final Color ZEBRA = new Color(248, 248, 248);
    private static final Color PASS_BG = new Color(232, 245, 233);
    private static final Color PASS_FG = new Color(27, 94, 32);
    private static final Color FAIL_BG = new Color(255, 235, 238);
    private static final Color FAIL_FG = new Color(183, 28, 28);
    private static final Color HEADER_BG = new Color(15, 76, 92);
    private static final float PAGE_MARGIN = 48f;

    private final QtktComplianceReportService reportService;

    public byte[] exportHandHygiene(
            LocalDate from, LocalDate to, Long departmentId, Long employeeId,
            String search, String resultFilter, String sortDir) {
        Map<String, Object> report = reportService.handHygieneReport(
                from, to, departmentId, employeeId, search, resultFilter, sortDir, 0, 500);
        return buildPdf(report, Mode.HAND_HYGIENE);
    }

    public byte[] exportTechnical(
            LocalDate from, LocalDate to, Long departmentId, Long employeeId, String procedureCode,
            String search, String resultFilter, String sortDir) {
        Map<String, Object> report = reportService.technicalReport(
                from, to, departmentId, employeeId, procedureCode, search, resultFilter, sortDir, 0, 500);
        return buildPdf(report, Mode.TECHNICAL);
    }

    public byte[] exportGdsk(
            LocalDate from, LocalDate to, Long departmentId, Long employeeId,
            String search, String resultFilter, String sortDir) {
        Map<String, Object> report = reportService.gdskReport(
                from, to, departmentId, employeeId, search, resultFilter, sortDir, 0, 500);
        return buildPdf(report, Mode.GDSK);
    }

    private enum Mode { HAND_HYGIENE, TECHNICAL, GDSK }

    @SuppressWarnings("unchecked")
    private byte[] buildPdf(Map<String, Object> report, Mode mode) {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Document doc = new Document(PageSize.A4.rotate(), PAGE_MARGIN, PAGE_MARGIN, 56, 64);
            PdfWriter writer = PdfWriter.getInstance(doc, out);
            Fonts fonts = Fonts.load();
            writer.setPageEvent(new PageDecor(String.valueOf(report.get("reportTitle")), fonts));
            doc.open();

            doc.add(buildLetterhead(report, fonts));
            doc.add(buildMetaTable(report, fonts));
            doc.add(spacer(10f));

            Map<String, Object> kpi = (Map<String, Object>) report.get("kpi");
            doc.add(sectionBanner("I. TÓM TẮT CHỈ SỐ", fonts));
            doc.add(buildKpiCards(kpi, fonts));
            if (report.get("formulaNote") != null) {
                Paragraph formula = new Paragraph(String.valueOf(report.get("formulaNote")), fonts.footnote);
                formula.setSpacingBefore(4f);
                formula.setSpacingAfter(4f);
                doc.add(formula);
            }
            doc.add(spacer(8f));

            doc.add(sectionBanner("II. THỐNG KÊ THEO KHOA", fonts));
            doc.add(buildDataTable(
                    new String[]{"STT", "Khoa", "Tổng đánh giá", "Đạt", "Không đạt", "Tỷ lệ tuân thủ"},
                    new float[]{0.5f, 3.2f, 1.1f, 0.9f, 1.1f, 1.2f},
                    new int[]{0, 0, 2, 2, 2, 2},
                    (List<Map<String, Object>>) report.get("byDepartment"),
                    (row, idx) -> new String[]{
                            String.valueOf(idx),
                            str(row.get("departmentName")),
                            str(row.get("total")),
                            str(row.get("passed")),
                            str(row.get("failed")),
                            formatRate(row.get("complianceRate")),
                    }, fonts, false));
            doc.add(spacer(10f));

            if (mode == Mode.HAND_HYGIENE) {
                doc.add(sectionBanner("III. THỐNG KÊ THEO THỜI ĐIỂM VỆ SINH TAY", fonts));
                doc.add(buildDataTable(
                        new String[]{"STT", "Thời điểm", "Tổng", "Đạt", "Không đạt", "Tuân thủ"},
                        new float[]{0.5f, 3.5f, 1f, 0.9f, 1.1f, 1.2f},
                        new int[]{0, 0, 2, 2, 2, 2},
                        (List<Map<String, Object>>) report.get("byCheckContext"),
                        (row, idx) -> new String[]{
                                String.valueOf(idx),
                                str(row.get("checkContextLabel")),
                                str(row.get("total")),
                                str(row.get("passed")),
                                str(row.get("failed")),
                                formatRate(row.get("complianceRate")),
                        }, fonts, false));
                doc.add(spacer(10f));
            } else if (mode == Mode.TECHNICAL) {
                doc.add(sectionBanner("III. THỐNG KÊ THEO QUY TRÌNH KỸ THUẬT", fonts));
                doc.add(buildDataTable(
                        new String[]{"STT", "Quy trình", "Tổng", "Đạt", "Không đạt", "Tỷ lệ"},
                        new float[]{0.5f, 3.2f, 1f, 0.9f, 1.1f, 1.2f},
                        new int[]{0, 0, 2, 2, 2, 2},
                        (List<Map<String, Object>>) report.get("byProcedure"),
                        (row, idx) -> new String[]{
                                String.valueOf(idx),
                                str(row.get("procedureName")),
                                str(row.get("total")),
                                str(row.get("passed")),
                                str(row.get("failed")),
                                formatRate(row.get("complianceRate")),
                        }, fonts, true));
                doc.add(spacer(10f));
            }

            doc.add(sectionBanner(mode == Mode.GDSK ? "III. DANH SÁCH TƯ VẤN CHI TIẾT" : "IV. DANH SÁCH ĐÁNH GIÁ CHI TIẾT", fonts));
            Map<String, Object> details = (Map<String, Object>) report.get("details");
            List<Map<String, Object>> items = (List<Map<String, Object>>) details.get("items");
            if (mode == Mode.HAND_HYGIENE) {
                doc.add(buildDataTable(
                        new String[]{"STT", "Ngày", "Khoa", "Nhân viên", "Thời điểm", "Điểm", "Kết quả"},
                        new float[]{0.45f, 0.9f, 1.8f, 1.8f, 2.4f, 0.65f, 0.9f},
                        new int[]{0, 1, 0, 0, 0, 2, 1},
                        items,
                        (row, idx) -> new String[]{
                                String.valueOf(idx),
                                str(row.get("evalDateLabel")),
                                str(row.get("departmentName")),
                                str(row.get("employeeName")),
                                str(row.get("checkContextLabel")),
                                str(row.get("totalScore")),
                                str(row.get("result")),
                        }, fonts, false, true));
            } else if (mode == Mode.GDSK) {
                doc.add(buildDataTable(
                        new String[]{"STT", "Ngày", "Khoa", "Nhân viên", "Mã BN", "Điểm", "Kết quả"},
                        new float[]{0.45f, 0.9f, 1.8f, 1.8f, 1.6f, 0.65f, 0.9f},
                        new int[]{0, 1, 0, 0, 1, 2, 1},
                        items,
                        (row, idx) -> new String[]{
                                String.valueOf(idx),
                                str(row.get("evalDateLabel")),
                                str(row.get("departmentName")),
                                str(row.get("employeeName")),
                                str(row.get("patientCode")),
                                str(row.get("totalScore")),
                                str(row.get("result")),
                        }, fonts, false, true));
            } else {
                doc.add(buildDataTable(
                        new String[]{"STT", "Ngày", "Khoa", "Nhân viên", "Quy trình", "Điểm", "Kết quả"},
                        new float[]{0.45f, 0.9f, 1.8f, 1.8f, 2.1f, 0.65f, 0.9f},
                        new int[]{0, 1, 0, 0, 0, 2, 1},
                        items,
                        (row, idx) -> new String[]{
                                String.valueOf(idx),
                                str(row.get("evalDateLabel")),
                                str(row.get("departmentName")),
                                str(row.get("employeeName")),
                                str(row.get("procedureName")),
                                str(row.get("totalScore")),
                                str(row.get("result")),
                        }, fonts, false, true));
            }

            doc.add(spacer(16f));
            doc.add(buildSignatureBlock(fonts));
            doc.add(spacer(6f));
            doc.add(new Paragraph(
                    "Ghi chú: Báo cáo tự động tổng hợp từ phiếu đánh giá đã hoàn thành. Không nhập tay tỷ lệ tuân thủ.",
                    fonts.footnote));

            doc.close();
            return out.toByteArray();
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file PDF: " + ex.getMessage());
        }
    }

    private PdfPTable buildLetterhead(Map<String, Object> report, Fonts f) throws DocumentException {
        PdfPTable table = new PdfPTable(1);
        table.setWidthPercentage(62);
        table.setHorizontalAlignment(Element.ALIGN_CENTER);
        table.setSpacingAfter(4f);

        PdfPCell org = cell(new Phrase("BỆNH VIỆN MINH AN", f.orgName), Element.ALIGN_CENTER);
        org.setBorder(Rectangle.NO_BORDER);
        org.setPaddingBottom(2f);
        table.addCell(org);

        PdfPCell dept = cell(new Phrase("PHÒNG ĐIỀU DƯỠNG", f.orgSub), Element.ALIGN_CENTER);
        dept.setBorder(Rectangle.NO_BORDER);
        dept.setPaddingBottom(6f);
        table.addCell(dept);

        PdfPCell line = new PdfPCell();
        line.setBorder(Rectangle.BOTTOM);
        line.setBorderWidthBottom(1.2f);
        line.setBorderColor(BRAND);
        line.setFixedHeight(4f);
        table.addCell(line);

        PdfPTable outer = new PdfPTable(1);
        outer.setWidthPercentage(100);
        outer.addCell(wrapCell(table));

        PdfPTable titleWrap = new PdfPTable(1);
        titleWrap.setWidthPercentage(100);
        titleWrap.setSpacingBefore(10f);
        PdfPCell titleCell = cell(new Phrase(String.valueOf(report.get("reportTitle")).toUpperCase(Locale.ROOT), f.reportTitle), Element.ALIGN_CENTER);
        titleCell.setBorder(Rectangle.NO_BORDER);
        titleCell.setPaddingTop(4f);
        titleCell.setPaddingBottom(2f);
        titleWrap.addCell(titleCell);

        PdfPCell sub = cell(new Phrase("(Báo cáo tự động từ hệ thống HRM)", f.reportSub), Element.ALIGN_CENTER);
        sub.setBorder(Rectangle.NO_BORDER);
        sub.setPaddingBottom(6f);
        titleWrap.addCell(sub);

        PdfPTable root = new PdfPTable(1);
        root.setWidthPercentage(100);
        root.addCell(wrapCell(outer));
        root.addCell(wrapCell(titleWrap));
        return root;
    }

    private PdfPTable buildMetaTable(Map<String, Object> report, Fonts f) throws DocumentException {
        PdfPTable table = new PdfPTable(new float[]{1.4f, 3.6f, 1.4f, 3.6f});
        table.setWidthPercentage(100);
        table.setSpacingBefore(6f);

        addMetaRow(table, f, "Kỳ báo cáo",
                formatIso(String.valueOf(report.get("from"))) + " – " + formatIso(String.valueOf(report.get("to"))),
                "Phạm vi", String.valueOf(report.get("departmentName")));
        addMetaRow(table, f, "Ngày xuất", LocalDate.now().format(DMY),
                "Loại báo cáo", String.valueOf(report.get("reportTitle")));

        return table;
    }

    private void addMetaRow(PdfPTable table, Fonts f, String l1, String v1, String l2, String v2) {
        table.addCell(metaLabel(l1, f));
        table.addCell(metaValue(v1, f));
        table.addCell(metaLabel(l2, f));
        table.addCell(metaValue(v2, f));
    }

    private PdfPCell metaLabel(String text, Fonts f) {
        PdfPCell cell = cell(new Phrase(text, f.metaLabel), Element.ALIGN_LEFT);
        cell.setBackgroundColor(BRAND_LIGHT);
        cell.setPadding(6f);
        cell.setBorderColor(BORDER);
        return cell;
    }

    private PdfPCell metaValue(String text, Fonts f) {
        PdfPCell cell = cell(new Phrase(text, f.metaValue), Element.ALIGN_LEFT);
        cell.setBackgroundColor(Color.WHITE);
        cell.setPadding(6f);
        cell.setBorderColor(BORDER);
        return cell;
    }

    private PdfPTable buildKpiCards(Map<String, Object> kpi, Fonts f) throws DocumentException {
        PdfPTable table = new PdfPTable(4);
        table.setWidthPercentage(100);
        table.setSpacingBefore(4f);
        Object[][] cards = {
                {"Tổng lần đánh giá", str(kpi.get("total")), new Color(245, 245, 245), INK},
                {"Số lần đạt", str(kpi.get("passed")), PASS_BG, PASS_FG},
                {"Số lần không đạt", str(kpi.get("failed")), FAIL_BG, FAIL_FG},
                {"Tỷ lệ tuân thủ", str(kpi.get("complianceRateLabel")), BRAND_LIGHT, BRAND},
        };
        for (Object[] card : cards) {
            PdfPCell cell = new PdfPCell();
            cell.setBorderColor(BORDER);
            cell.setBorderWidth(0.8f);
            cell.setPaddingTop(8f);
            cell.setPaddingBottom(10f);
            cell.setPaddingLeft(8f);
            cell.setPaddingRight(8f);
            cell.setBackgroundColor((Color) card[2]);
            cell.setHorizontalAlignment(Element.ALIGN_CENTER);
            Paragraph p = new Paragraph();
            p.setAlignment(Element.ALIGN_CENTER);
            p.add(new Chunk((String) card[0] + "\n", f.kpiLabel));
            Font val = f.kpiValue((Color) card[3]);
            p.add(new Chunk((String) card[1], val));
            cell.addElement(p);
            table.addCell(cell);
        }
        return table;
    }

    private PdfPTable sectionBanner(String text, Fonts f) {
        PdfPTable bar = new PdfPTable(1);
        bar.setWidthPercentage(100);
        bar.setSpacingBefore(4f);
        bar.setSpacingAfter(2f);
        PdfPCell cell = cell(new Phrase(text, f.section), Element.ALIGN_LEFT);
        cell.setBackgroundColor(BRAND_LIGHT);
        cell.setBorder(Rectangle.LEFT | Rectangle.TOP | Rectangle.BOTTOM | Rectangle.RIGHT);
        cell.setBorderWidthLeft(3f);
        cell.setBorderColorLeft(BRAND);
        cell.setBorderColor(BORDER);
        cell.setPaddingTop(6f);
        cell.setPaddingBottom(6f);
        cell.setPaddingLeft(10f);
        bar.addCell(cell);
        return bar;
    }

    @FunctionalInterface
    private interface IndexedRowMapper {
        String[] map(Map<String, Object> row, int index);
    }

    private PdfPTable buildDataTable(
            String[] headers, float[] widths, int[] aligns, List<Map<String, Object>> rows,
            IndexedRowMapper mapper, Fonts f, boolean highlightTotal) throws DocumentException {
        return buildDataTable(headers, widths, aligns, rows, mapper, f, highlightTotal, false);
    }

    private PdfPTable buildDataTable(
            String[] headers, float[] widths, int[] aligns, List<Map<String, Object>> rows,
            IndexedRowMapper mapper, Fonts f, boolean highlightTotal, boolean resultColumn) throws DocumentException {
        PdfPTable table = new PdfPTable(headers.length);
        table.setWidthPercentage(100);
        table.setWidths(widths);
        table.setSpacingBefore(4f);
        table.setHeaderRows(1);

        for (String h : headers) {
            table.addCell(headerCell(h, f));
        }

        if (rows == null || rows.isEmpty()) {
            PdfPCell empty = cell(new Phrase("Chưa có dữ liệu", f.body), Element.ALIGN_CENTER);
            empty.setColspan(headers.length);
            empty.setPadding(14f);
            empty.setBackgroundColor(ZEBRA);
            empty.setBorderColor(BORDER);
            table.addCell(empty);
            return table;
        }

        int idx = 1;
        for (Map<String, Object> row : rows) {
            String[] values = mapper.map(row, idx++);
            boolean total = highlightTotal && Boolean.TRUE.equals(row.get("isTotal"));
            boolean zebra = idx % 2 == 0;
            for (int c = 0; c < values.length; c++) {
                boolean isResult = resultColumn && c == values.length - 1;
                table.addCell(bodyCell(values[c], f, aligns[c], zebra, total, isResult));
            }
        }
        return table;
    }

    private PdfPCell headerCell(String text, Fonts f) {
        PdfPCell cell = cell(new Phrase(text, f.header), Element.ALIGN_CENTER);
        cell.setBackgroundColor(HEADER_BG);
        cell.setBorderColor(HEADER_BG);
        cell.setPaddingTop(7f);
        cell.setPaddingBottom(7f);
        cell.setVerticalAlignment(Element.ALIGN_MIDDLE);
        return cell;
    }

    private PdfPCell bodyCell(String text, Fonts f, int align, boolean zebra, boolean total, boolean resultCol) {
        Font font = f.body;
        Color bg = Color.WHITE;
        if (total) {
            bg = new Color(230, 230, 230);
            font = f.bodyBold;
        } else if (resultCol) {
            if ("Đạt".equalsIgnoreCase(text)) {
                bg = PASS_BG;
                font = f.pass;
            } else if (text != null && text.toLowerCase(Locale.ROOT).contains("không")) {
                bg = FAIL_BG;
                font = f.fail;
            } else if (zebra) {
                bg = ZEBRA;
            }
        } else if (zebra) {
            bg = ZEBRA;
        }
        PdfPCell cell = cell(new Phrase(text == null ? "" : text, font), align);
        cell.setBackgroundColor(bg);
        cell.setPaddingTop(5f);
        cell.setPaddingBottom(5f);
        cell.setPaddingLeft(5f);
        cell.setPaddingRight(5f);
        cell.setBorderColor(BORDER);
        cell.setVerticalAlignment(Element.ALIGN_MIDDLE);
        return cell;
    }

    private PdfPTable buildSignatureBlock(Fonts f) throws DocumentException {
        PdfPTable table = new PdfPTable(2);
        table.setWidthPercentage(70);
        table.setHorizontalAlignment(Element.ALIGN_RIGHT);
        table.setWidths(new float[]{1f, 1f});

        PdfPCell left = cell(new Phrase("Người lập báo cáo\n\n\n\n(Ký, ghi rõ họ tên)", f.signLabel), Element.ALIGN_CENTER);
        left.setBorder(Rectangle.NO_BORDER);
        left.setPaddingTop(8f);
        table.addCell(left);

        PdfPCell right = cell(new Phrase("Trưởng khoa / Phụ trách\n\n\n\n(Ký, ghi rõ họ tên)", f.signLabel), Element.ALIGN_CENTER);
        right.setBorder(Rectangle.NO_BORDER);
        right.setPaddingTop(8f);
        table.addCell(right);
        return table;
    }

    private PdfPCell cell(Phrase phrase, int align) {
        PdfPCell cell = new PdfPCell(phrase);
        cell.setHorizontalAlignment(align);
        cell.setVerticalAlignment(Element.ALIGN_MIDDLE);
        return cell;
    }

    private PdfPCell wrapCell(PdfPTable inner) {
        PdfPCell cell = new PdfPCell(inner);
        cell.setBorder(Rectangle.NO_BORDER);
        cell.setPadding(0f);
        return cell;
    }

    private Paragraph spacer(float pts) {
        Paragraph p = new Paragraph(" ");
        p.setSpacingBefore(pts);
        return p;
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

    private static String str(Object o) {
        return o == null ? "" : String.valueOf(o);
    }

    private static class Fonts {
        final Font orgName;
        final Font orgSub;
        final Font reportTitle;
        final Font reportSub;
        final Font metaLabel;
        final Font metaValue;
        final Font section;
        final Font header;
        final Font body;
        final Font bodyBold;
        final Font kpiLabel;
        final Font footnote;
        final Font signLabel;
        final Font pass;
        final Font fail;
        private final BaseFont regular;
        private final BaseFont bold;

        Fonts(BaseFont regular, BaseFont bold) {
            this.regular = regular;
            this.bold = bold;
            orgName = sized(bold, 13f, INK);
            orgSub = sized(bold, 11f, BRAND);
            reportTitle = sized(bold, 14f, INK);
            reportSub = sized(regular, 10f, MUTED);
            metaLabel = sized(bold, 10f, INK);
            metaValue = sized(regular, 10f, INK);
            section = sized(bold, 11f, BRAND);
            header = sized(bold, 10f, Color.WHITE);
            body = sized(regular, 10f, INK);
            bodyBold = sized(bold, 10f, INK);
            kpiLabel = sized(bold, 9f, MUTED);
            footnote = sized(regular, 9f, MUTED);
            signLabel = sized(bold, 10f, INK);
            pass = sized(bold, 10f, PASS_FG);
            fail = sized(bold, 10f, FAIL_FG);
        }

        Font kpiValue(Color color) {
            return sized(bold, 15f, color);
        }

        private static Font sized(BaseFont bf, float size, Color color) {
            Font f = new Font(bf, size, Font.NORMAL, color);
            f.setFamily(FONT_REGULAR);
            return f;
        }

        static Fonts load() throws Exception {
            FontFiles files = resolveFontFiles();
            BaseFont regular = BaseFont.createFont(files.regular, BaseFont.IDENTITY_H, BaseFont.EMBEDDED);
            BaseFont bold = BaseFont.createFont(files.bold, BaseFont.IDENTITY_H, BaseFont.EMBEDDED);
            return new Fonts(regular, bold);
        }
    }

    private record FontFiles(String regular, String bold) {}

    private static FontFiles resolveFontFiles() throws Exception {
        String[][] pairs = {
                {"C:/Windows/Fonts/times.ttf", "C:/Windows/Fonts/timesbd.ttf"},
                {"C:/Windows/Fonts/Times New Roman.ttf", "C:/Windows/Fonts/Times New Roman Bold.ttf"},
                {"/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman.ttf",
                        "/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Bold.ttf"},
                {"/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf",
                        "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf"},
        };
        for (String[] pair : pairs) {
            if (Files.exists(Path.of(pair[0])) && Files.exists(Path.of(pair[1]))) {
                return new FontFiles(pair[0], pair[1]);
            }
        }
        if (Files.exists(Path.of("C:/Windows/Fonts/times.ttf"))) {
            String p = "C:/Windows/Fonts/times.ttf";
            return new FontFiles(p, p);
        }
        throw new IllegalStateException("Không tìm thấy font Times New Roman trên hệ thống.");
    }

    private static class PageDecor extends PdfPageEventHelper {
        private final String title;
        private final Fonts fonts;
        private final BaseFont footerFont;

        PageDecor(String title, Fonts fonts) throws Exception {
            this.title = title;
            this.fonts = fonts;
            this.footerFont = fonts.regular;
        }

        @Override
        public void onEndPage(PdfWriter writer, Document document) {
            PdfContentByte cb = writer.getDirectContent();
            float pageW = document.getPageSize().getWidth();
            float yLine = document.bottomMargin() - 14f;

            cb.setColorStroke(BORDER);
            cb.setLineWidth(0.6f);
            cb.moveTo(document.leftMargin(), yLine + 10f);
            cb.lineTo(pageW - document.rightMargin(), yLine + 10f);
            cb.stroke();

            Font left = new Font(footerFont, 8.5f, Font.NORMAL, MUTED);
            left.setFamily(FONT_REGULAR);
            Font right = new Font(footerFont, 8.5f, Font.NORMAL, MUTED);
            right.setFamily(FONT_REGULAR);

            ColumnText.showTextAligned(cb, Element.ALIGN_LEFT,
                    new Phrase("Bệnh viện Minh An — HRM", left),
                    document.leftMargin(), yLine, 0);
            ColumnText.showTextAligned(cb, Element.ALIGN_CENTER,
                    new Phrase(title, left),
                    pageW / 2f, yLine, 0);
            ColumnText.showTextAligned(cb, Element.ALIGN_RIGHT,
                    new Phrase("Trang " + writer.getPageNumber(), right),
                    pageW - document.rightMargin(), yLine, 0);
        }
    }
}
