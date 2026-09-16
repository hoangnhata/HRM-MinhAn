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
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class NursingActivityReportPdfService {

    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final Color BRAND = new Color(15, 118, 110);
    private static final Color BRAND_DARK = new Color(15, 76, 92);
    private static final Color BRAND_LIGHT = new Color(230, 247, 245);
    private static final Color INK = new Color(15, 23, 42);
    private static final Color MUTED = new Color(100, 116, 139);
    private static final Color BORDER = new Color(203, 213, 225);
    private static final Color ZEBRA = new Color(248, 250, 252);
    private static final Color KPI_BG = new Color(240, 253, 250);
    private static final float PAGE_MARGIN = 42f;

    private final NursingActivityReportService reportService;

    public byte[] export(NursingActivityReportService.ReportKind kind, LocalDate from, LocalDate to, Long departmentId) {
        Map<String, Object> report = loadReport(kind, from, to, departmentId);
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Document doc = new Document(PageSize.A4.rotate(), PAGE_MARGIN, PAGE_MARGIN, 52, 58);
            PdfWriter writer = PdfWriter.getInstance(doc, out);
            Fonts fonts = Fonts.load();
            writer.setPageEvent(new PageDecor(String.valueOf(report.get("reportTitle")), fonts));
            doc.open();

            doc.add(buildLetterhead(report, fonts));
            doc.add(buildMetaTable(report, fonts));
            doc.add(spacer(10f));

            doc.add(sectionBanner("I. CHỈ SỐ TỔNG HỢP", fonts));
            doc.add(buildKpiCards(report, kind, fonts));
            doc.add(spacer(10f));

            doc.add(sectionBanner("II. THỐNG KÊ THEO KHOA", fonts));
            doc.add(buildDeptTable(report, kind, fonts));

            doc.add(spacer(18f));
            doc.add(buildSignatureBlock(fonts));
            doc.add(spacer(6f));
            doc.add(new Paragraph(
                    "Ghi chú: Báo cáo tự động tính từ báo cáo hoạt động điều dưỡng hằng ngày. Không nhập tay các chỉ số.",
                    fonts.footnote));

            doc.close();
            return out.toByteArray();
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file PDF: " + ex.getMessage());
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

    private PdfPTable buildLetterhead(Map<String, Object> report, Fonts f) throws DocumentException {
        PdfPTable inner = new PdfPTable(1);
        inner.setWidthPercentage(62);
        inner.setHorizontalAlignment(Element.ALIGN_CENTER);

        PdfPCell org = plain(new Phrase("BỆNH VIỆN MINH AN", f.orgName), Element.ALIGN_CENTER);
        org.setPaddingBottom(2f);
        inner.addCell(org);

        PdfPCell dept = plain(new Phrase("PHÒNG ĐIỀU DƯỠNG", f.orgSub), Element.ALIGN_CENTER);
        dept.setPaddingBottom(6f);
        inner.addCell(dept);

        PdfPCell line = new PdfPCell();
        line.setBorder(Rectangle.BOTTOM);
        line.setBorderWidthBottom(1.4f);
        line.setBorderColor(BRAND);
        line.setFixedHeight(4f);
        inner.addCell(line);

        PdfPTable titleWrap = new PdfPTable(1);
        titleWrap.setWidthPercentage(100);
        titleWrap.setSpacingBefore(10f);
        PdfPCell title = plain(
                new Phrase(String.valueOf(report.get("reportTitle")).toUpperCase(Locale.ROOT), f.reportTitle),
                Element.ALIGN_CENTER);
        title.setPaddingTop(4f);
        title.setPaddingBottom(2f);
        titleWrap.addCell(title);

        PdfPCell sub = plain(new Phrase("(Báo cáo hoạt động điều dưỡng — tự động từ hệ thống HRM)", f.reportSub), Element.ALIGN_CENTER);
        sub.setPaddingBottom(4f);
        titleWrap.addCell(sub);

        PdfPTable root = new PdfPTable(1);
        root.setWidthPercentage(100);
        root.addCell(wrap(inner));
        root.addCell(wrap(titleWrap));
        return root;
    }

    private PdfPTable buildMetaTable(Map<String, Object> report, Fonts f) throws DocumentException {
        PdfPTable table = new PdfPTable(new float[]{1.4f, 3.6f, 1.4f, 3.6f});
        table.setWidthPercentage(100);
        table.setSpacingBefore(8f);
        addMeta(table, f, "Kỳ báo cáo", str(report.get("fromLabel")) + " – " + str(report.get("toLabel")),
                "Phạm vi", str(report.get("departmentName")));
        addMeta(table, f, "Ngày xuất", LocalDate.now().format(DMY),
                "Loại báo cáo", str(report.get("reportTitle")));
        return table;
    }

    private void addMeta(PdfPTable table, Fonts f, String l1, String v1, String l2, String v2) {
        table.addCell(metaLabel(l1, f));
        table.addCell(metaValue(v1, f));
        table.addCell(metaLabel(l2, f));
        table.addCell(metaValue(v2, f));
    }

    private PdfPCell metaLabel(String text, Fonts f) {
        PdfPCell cell = cell(new Phrase(text, f.metaLabel), Element.ALIGN_LEFT);
        cell.setBackgroundColor(BRAND_LIGHT);
        cell.setPadding(7f);
        cell.setBorderColor(BORDER);
        return cell;
    }

    private PdfPCell metaValue(String text, Fonts f) {
        PdfPCell cell = cell(new Phrase(text, f.metaValue), Element.ALIGN_LEFT);
        cell.setBackgroundColor(Color.WHITE);
        cell.setPadding(7f);
        cell.setBorderColor(BORDER);
        return cell;
    }

    @SuppressWarnings("unchecked")
    private PdfPTable buildKpiCards(
            Map<String, Object> report, NursingActivityReportService.ReportKind kind, Fonts f)
            throws DocumentException {
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

        int cols = Math.max(1, Math.min(cards.size(), 5));
        PdfPTable table = new PdfPTable(cols);
        table.setWidthPercentage(100);
        table.setSpacingBefore(4f);

        if (cards.isEmpty()) {
            PdfPCell empty = cell(new Phrase("Chưa có chỉ số", f.body), Element.ALIGN_CENTER);
            empty.setColspan(cols);
            empty.setPadding(12f);
            empty.setBackgroundColor(ZEBRA);
            empty.setBorderColor(BORDER);
            table.addCell(empty);
            return table;
        }

        for (String[] card : cards) {
            PdfPCell cell = new PdfPCell();
            cell.setBorderColor(BORDER);
            cell.setBorderWidth(0.8f);
            cell.setPaddingTop(9f);
            cell.setPaddingBottom(11f);
            cell.setPaddingLeft(8f);
            cell.setPaddingRight(8f);
            cell.setBackgroundColor(KPI_BG);
            cell.setHorizontalAlignment(Element.ALIGN_CENTER);
            Paragraph p = new Paragraph();
            p.setAlignment(Element.ALIGN_CENTER);
            p.add(new Chunk(card[0].toUpperCase(Locale.ROOT) + "\n", f.kpiLabel));
            p.add(new Chunk(card[1], f.kpiValue));
            cell.addElement(p);
            table.addCell(cell);
        }

        if (kind == NursingActivityReportService.ReportKind.OVERVIEW) {
            Map<String, Object> ov = (Map<String, Object>) report.get("overviewKpi");
            if (ov != null) {
                PdfPTable detail = new PdfPTable(2);
                detail.setWidthPercentage(100);
                detail.setSpacingBefore(8f);
                detail.setWidths(new float[]{2.2f, 3.8f});
                addDetailRow(detail, f, "Té ngã — Tần suất", nested(ov, "falls", "frequencyLabel"));
                addDetailRow(detail, f, "Loét tì đè — Tần suất", nested(ov, "pressureUlcers", "frequencyLabel"));
                PdfPTable wrap = new PdfPTable(1);
                wrap.setWidthPercentage(100);
                wrap.addCell(wrap(table));
                wrap.addCell(wrap(detail));
                return wrap;
            }
        }
        return table;
    }

    private void addDetailRow(PdfPTable table, Fonts f, String label, String value) {
        PdfPCell lc = cell(new Phrase(label, f.metaLabel), Element.ALIGN_LEFT);
        lc.setBackgroundColor(BRAND_LIGHT);
        lc.setPadding(6f);
        lc.setBorderColor(BORDER);
        table.addCell(lc);
        PdfPCell vc = cell(new Phrase(value, f.body), Element.ALIGN_LEFT);
        vc.setPadding(6f);
        vc.setBorderColor(BORDER);
        table.addCell(vc);
    }

    @SuppressWarnings("unchecked")
    private PdfPTable buildDeptTable(
            Map<String, Object> report, NursingActivityReportService.ReportKind kind, Fonts f)
            throws DocumentException {
        List<Map<String, Object>> rows = kind == NursingActivityReportService.ReportKind.OVERVIEW
                ? (List<Map<String, Object>>) report.get("summaryTable")
                : (List<Map<String, Object>>) report.get("byDepartment");

        String[] headers = switch (kind) {
            case OVERVIEW -> new String[]{"STT", "Khoa", "Té ngã %", "Té ngã/1000", "Loét %", "Loét/1000", "ĐD/NB", "Nhầm/1000", "Sai sót %"};
            case FALLS -> new String[]{"STT", "Khoa", "Ca té ngã", "NB nội trú", "Ngày NV", "Tỷ lệ", "Tần suất"};
            case PRESSURE_ULCER -> new String[]{"STT", "Khoa", "Ca loét", "NB nội trú", "Ngày NV", "Tỷ lệ", "Tần suất"};
            case NURSE_BED -> new String[]{"STT", "Khoa", "ĐD đi làm", "NB nội trú", "Tỷ lệ"};
            case ID_MIXUP -> new String[]{"STT", "Khoa", "Số ca", "Ngày NV", "Tần suất"};
            case MEDICATION_ERROR -> new String[]{"STT", "Khoa", "NB sai sót", "NB nội trú", "Tỷ lệ"};
        };

        float[] widths = switch (kind) {
            case OVERVIEW -> new float[]{0.45f, 2.4f, 0.9f, 1.05f, 0.85f, 1.0f, 1.0f, 1.0f, 0.95f};
            case FALLS, PRESSURE_ULCER -> new float[]{0.5f, 2.6f, 1.0f, 1.1f, 1.1f, 0.9f, 1.1f};
            case NURSE_BED -> new float[]{0.5f, 3.2f, 1.2f, 1.2f, 1.4f};
            case ID_MIXUP, MEDICATION_ERROR -> new float[]{0.5f, 3.2f, 1.3f, 1.4f, 1.4f};
        };

        PdfPTable table = new PdfPTable(headers.length);
        table.setWidthPercentage(100);
        table.setWidths(widths);
        table.setSpacingBefore(4f);
        table.setHeaderRows(1);

        for (String h : headers) {
            PdfPCell cell = cell(new Phrase(h, f.header), Element.ALIGN_CENTER);
            cell.setBackgroundColor(BRAND);
            cell.setBorderColor(BRAND);
            cell.setPaddingTop(7f);
            cell.setPaddingBottom(7f);
            table.addCell(cell);
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

        int stt = 1;
        for (Map<String, Object> row : rows) {
            String[] vals = deptValues(row, kind, stt++);
            boolean zebra = stt % 2 == 0;
            for (int i = 0; i < vals.length; i++) {
                int align = (i == 1) ? Element.ALIGN_LEFT : Element.ALIGN_CENTER;
                Font font = (i == 1) ? f.bodyBold : f.body;
                PdfPCell cell = cell(new Phrase(vals[i], font), align);
                cell.setBackgroundColor(zebra ? ZEBRA : Color.WHITE);
                cell.setBorderColor(BORDER);
                cell.setPaddingTop(5f);
                cell.setPaddingBottom(5f);
                cell.setPaddingLeft(4f);
                cell.setPaddingRight(4f);
                table.addCell(cell);
            }
        }
        return table;
    }

    private String[] deptValues(Map<String, Object> row, NursingActivityReportService.ReportKind kind, int stt) {
        if (kind == NursingActivityReportService.ReportKind.OVERVIEW) {
            return new String[]{
                    String.valueOf(stt), str(row.get("departmentName")),
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
                    String.valueOf(stt), str(row.get("departmentName")), str(row.get("newPressureUlcers")),
                    str(row.get("inpatients")), str(row.get("inpatientTreatmentDays")),
                    str(row.get("pressureUlcerRateLabel")), str(row.get("pressureUlcerFrequencyLabel")),
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

    private PdfPTable sectionBanner(String text, Fonts f) {
        PdfPTable bar = new PdfPTable(1);
        bar.setWidthPercentage(100);
        bar.setSpacingBefore(2f);
        bar.setSpacingAfter(2f);
        PdfPCell cell = cell(new Phrase(text, f.section), Element.ALIGN_LEFT);
        cell.setBackgroundColor(BRAND_LIGHT);
        cell.setBorder(Rectangle.BOX);
        cell.setBorderWidthLeft(3.2f);
        cell.setBorderColorLeft(BRAND);
        cell.setBorderColor(BORDER);
        cell.setPaddingTop(7f);
        cell.setPaddingBottom(7f);
        cell.setPaddingLeft(10f);
        bar.addCell(cell);
        return bar;
    }

    private PdfPTable buildSignatureBlock(Fonts f) throws DocumentException {
        PdfPTable table = new PdfPTable(2);
        table.setWidthPercentage(72);
        table.setHorizontalAlignment(Element.ALIGN_RIGHT);
        table.setWidths(new float[]{1f, 1f});

        PdfPCell left = plain(new Phrase("Người lập báo cáo\n\n\n\n(Ký, ghi rõ họ tên)", f.signLabel), Element.ALIGN_CENTER);
        left.setPaddingTop(8f);
        table.addCell(left);

        PdfPCell right = plain(new Phrase("Trưởng khoa / Phụ trách\n\n\n\n(Ký, ghi rõ họ tên)", f.signLabel), Element.ALIGN_CENTER);
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

    private PdfPCell plain(Phrase phrase, int align) {
        PdfPCell cell = cell(phrase, align);
        cell.setBorder(Rectangle.NO_BORDER);
        return cell;
    }

    private PdfPCell wrap(PdfPTable inner) {
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

    @SuppressWarnings("unchecked")
    private static String nested(Map<String, Object> group, String key, String field) {
        Map<String, Object> item = (Map<String, Object>) group.get(key);
        return item != null ? str(item.get(field)) : "—";
    }

    private static String str(Object o) {
        return o == null ? "—" : String.valueOf(o);
    }

    private static class Fonts {
        final Font orgName, orgSub, reportTitle, reportSub, metaLabel, metaValue;
        final Font section, header, body, bodyBold, kpiLabel, kpiValue, footnote, signLabel;

        Fonts(BaseFont regular, BaseFont bold) {
            orgName = new Font(bold, 13f, Font.NORMAL, INK);
            orgSub = new Font(bold, 11f, Font.NORMAL, BRAND);
            reportTitle = new Font(bold, 13.5f, Font.NORMAL, BRAND_DARK);
            reportSub = new Font(regular, 9f, Font.ITALIC, MUTED);
            metaLabel = new Font(bold, 9f, Font.NORMAL, BRAND_DARK);
            metaValue = new Font(regular, 10f, Font.NORMAL, INK);
            section = new Font(bold, 11f, Font.NORMAL, BRAND_DARK);
            header = new Font(bold, 8.5f, Font.NORMAL, Color.WHITE);
            body = new Font(regular, 9f, Font.NORMAL, INK);
            bodyBold = new Font(bold, 9f, Font.NORMAL, INK);
            kpiLabel = new Font(bold, 8f, Font.NORMAL, MUTED);
            kpiValue = new Font(bold, 12f, Font.NORMAL, BRAND);
            footnote = new Font(regular, 8.5f, Font.ITALIC, MUTED);
            signLabel = new Font(regular, 9.5f, Font.NORMAL, INK);
        }

        static Fonts load() throws Exception {
            String reg = "C:/Windows/Fonts/times.ttf";
            String bd = "C:/Windows/Fonts/timesbd.ttf";
            if (!Files.exists(Path.of(reg))) throw new IllegalStateException("Không tìm thấy Times New Roman");
            if (!Files.exists(Path.of(bd))) bd = reg;
            return new Fonts(
                    BaseFont.createFont(reg, BaseFont.IDENTITY_H, BaseFont.EMBEDDED),
                    BaseFont.createFont(bd, BaseFont.IDENTITY_H, BaseFont.EMBEDDED));
        }
    }

    private static class PageDecor extends PdfPageEventHelper {
        private final String title;
        private final Font footerFont;
        private final Color lineColor = BRAND;

        PageDecor(String title, Fonts fonts) {
            this.title = title;
            this.footerFont = fonts.footnote;
        }

        @Override
        public void onEndPage(PdfWriter writer, Document document) {
            PdfContentByte cb = writer.getDirectContent();
            float left = document.left();
            float right = document.right();
            float bottom = document.bottom() - 18f;
            float top = document.top() + 14f;

            cb.setColorStroke(lineColor);
            cb.setLineWidth(0.7f);
            cb.moveTo(left, top);
            cb.lineTo(right, top);
            cb.stroke();

            cb.setColorStroke(BORDER);
            cb.setLineWidth(0.5f);
            cb.moveTo(left, bottom + 12f);
            cb.lineTo(right, bottom + 12f);
            cb.stroke();

            ColumnText.showTextAligned(
                    cb,
                    Element.ALIGN_LEFT,
                    new Phrase("Bệnh viện Minh An — HRM", footerFont),
                    left, bottom, 0);
            ColumnText.showTextAligned(
                    cb,
                    Element.ALIGN_CENTER,
                    new Phrase(title, footerFont),
                    (left + right) / 2f, bottom, 0);
            ColumnText.showTextAligned(
                    cb,
                    Element.ALIGN_RIGHT,
                    new Phrase("Trang " + writer.getPageNumber(), footerFont),
                    right, bottom, 0);
        }
    }
}
