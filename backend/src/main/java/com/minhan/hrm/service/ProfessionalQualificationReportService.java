package com.minhan.hrm.service;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import com.minhan.hrm.service.DegreeLevelNormalizer.Level;
import com.minhan.hrm.service.ProfessionClassifier.Profession;
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
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Báo cáo trình độ chuyên môn theo đối tượng nghề nghiệp
 * (Bác sĩ, Điều dưỡng, Hộ sinh, KTV, Y sĩ, Dược sĩ),
 * lấy từ trường «Trình độ / bằng cấp» trên hồ sơ nhân lực.
 */
@Service
@RequiredArgsConstructor
public class ProfessionalQualificationReportService {

    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final DateTimeFormatter TS = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm").withZone(VN);
    private static final String FONT = "Times New Roman";
    private static final String BRAND = "0F766E";
    private static final String BRAND_DARK = "0F4C5C";
    private static final String BRAND_LIGHT = "E6F7F5";
    private static final String HEADER_TEXT = "FFFFFF";
    private static final String INK = "0F172A";
    private static final String MUTED = "64748B";
    private static final String BORDER = "CBD5E1";
    private static final String ZEBRA = "F8FAFC";

    private static final List<Profession> TARGET_PROFESSIONS = List.of(
            Profession.DOCTOR,
            Profession.NURSE,
            Profession.MIDWIFE,
            Profession.TECHNICIAN,
            Profession.ASSISTANT_PHYSICIAN,
            Profession.PHARMACIST
    );

    private static final List<Level> DEGREE_LEVELS = List.of(
            Level.TIEN_SI, Level.THAC_SI, Level.CK2, Level.CK1,
            Level.DAI_HOC, Level.CAO_DANG, Level.TRUNG_CAP, Level.SO_CAP,
            Level.OTHER, Level.MISSING
    );

    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;

    @Transactional(readOnly = true)
    public Map<String, Object> overview() {
        ReportData data = buildData();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("generatedAt", Instant.now().toString());
        out.put("generatedAtLabel", TS.format(Instant.now()));
        out.put("totalHospitalStaff", data.allActive.size());
        out.put("totalInScope", data.rows.size());
        out.put("missingDegreeCount", data.rows.stream().filter(r -> r.level == Level.MISSING).count());
        out.put("withDegreeCount", data.rows.stream().filter(r -> r.level != Level.MISSING).count());
        out.put("professionOrder", TARGET_PROFESSIONS.stream().map(Enum::name).toList());
        out.put("degreeLevelOrder", DEGREE_LEVELS.stream().map(Enum::name).toList());
        out.put("degreeLevelLabels", DEGREE_LEVELS.stream()
                .collect(Collectors.toMap(Enum::name, DegreeLevelNormalizer::label, (a, b) -> a, LinkedHashMap::new)));
        out.put("byProfession", buildProfessionBlocks(data));
        out.put("degreeMatrix", buildDegreeMatrix(data));
        out.put("kpiCards", buildKpiCards(data));
        out.put("details", data.rows.stream().map(this::toDetailMap).toList());
        out.put("practiceCertificate", buildPracticeCertificateBlock(data));
        return out;
    }

    @Transactional(readOnly = true)
    public byte[] exportExcel() {
        ReportData data = buildData();
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Styles s = new Styles(wb);
            writeOverviewSheet(wb, s, data);
            writeMatrixSheet(wb, s, data);
            writeProfessionSheets(wb, s, data);
            writePracticeCertificateSheet(wb, s, data);
            writeDetailSheet(wb, s, data);
            applyPrintSetup(wb);
            wb.write(out);
            return out.toByteArray();
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "Không tạo được file Excel: " + ex.getMessage());
        }
    }

    private ReportData buildData() {
        List<Employee> all = employeeRepository.findAllWithDepartment().stream()
                .filter(e -> e.getStatus() != EmployeeStatus.TERMINATED)
                .toList();
        Map<Long, EmployeeWorkforceDetails> wfByEmp = workforceDetailsRepository.findByEmployeeIn(all).stream()
                .collect(Collectors.toMap(w -> w.getEmployee().getId(), w -> w, (a, b) -> a));

        List<EmployeeRow> rows = new ArrayList<>();
        for (Employee e : all) {
            String title = e.getPosition() != null ? e.getPosition().getTitle() : null;
            Profession profession = ProfessionClassifier.classify(title);
            if (!ProfessionClassifier.isTargetProfession(profession)) {
                continue;
            }
            EmployeeWorkforceDetails wf = wfByEmp.get(e.getId());
            String degreeRaw = wf != null && wf.getDegree() != null ? wf.getDegree().trim() : "";
            Level level = DegreeLevelNormalizer.normalize(degreeRaw.isEmpty() ? null : degreeRaw);
            String certNumber = wf != null ? blankToEmpty(wf.getPracticeCertNumber()) : "";
            String certDateRaw = wf != null ? blankToEmpty(wf.getPracticeCertDateRaw()) : "";
            String scope = wf != null ? blankToEmpty(wf.getPracticeScope()) : "";
            rows.add(new EmployeeRow(
                    e.getId(),
                    e.getEmployeeCode(),
                    e.getFullName(),
                    e.getDepartment() != null ? e.getDepartment().getName() : "",
                    e.getDepartment() != null ? e.getDepartment().getId() : null,
                    title != null ? title : "",
                    e.getStatus() != null ? e.getStatus().name() : "",
                    profession,
                    degreeRaw,
                    level,
                    PracticeCert.of(certNumber, certDateRaw, scope, LocalDate.now(VN))
            ));
        }
        rows.sort(Comparator
                .comparingInt((EmployeeRow r) -> ProfessionClassifier.sortOrder(r.profession))
                .thenComparing(r -> r.departmentName, String.CASE_INSENSITIVE_ORDER)
                .thenComparing(r -> r.fullName, String.CASE_INSENSITIVE_ORDER));
        return new ReportData(all, rows);
    }

    private List<Map<String, Object>> buildKpiCards(ReportData data) {
        List<Map<String, Object>> cards = new ArrayList<>();
        for (Profession p : TARGET_PROFESSIONS) {
            List<EmployeeRow> subset = data.rows.stream().filter(r -> r.profession == p).toList();
            long missing = subset.stream().filter(r -> r.level == Level.MISSING).count();
            Map<String, Object> card = new LinkedHashMap<>();
            card.put("code", p.name());
            card.put("label", ProfessionClassifier.label(p));
            card.put("total", subset.size());
            card.put("withDegree", subset.size() - missing);
            card.put("missingDegree", missing);
            card.put("missingPercent", pct(missing, subset.size()));
            cards.add(card);
        }
        return cards;
    }

    private List<Map<String, Object>> buildProfessionBlocks(ReportData data) {
        List<Map<String, Object>> blocks = new ArrayList<>();
        for (Profession p : TARGET_PROFESSIONS) {
            List<EmployeeRow> subset = data.rows.stream().filter(r -> r.profession == p).toList();
            Map<String, Object> block = new LinkedHashMap<>();
            block.put("code", p.name());
            block.put("label", ProfessionClassifier.label(p));
            block.put("total", subset.size());
            long missing = subset.stream().filter(r -> r.level == Level.MISSING).count();
            block.put("withDegree", subset.size() - missing);
            block.put("missingDegree", missing);
            block.put("byDegreeLevel", degreeLevelBreakdown(subset));
            block.put("rawDegreeBreakdown", rawDegreeBreakdown(subset));
            block.put("byDepartment", departmentBreakdown(subset));
            block.put("byStatus", statusBreakdown(subset));
            blocks.add(block);
        }
        return blocks;
    }

    private Map<String, Object> buildDegreeMatrix(ReportData data) {
        Map<String, Object> matrix = new LinkedHashMap<>();
        List<Map<String, Object>> columns = TARGET_PROFESSIONS.stream().map(p -> {
            Map<String, Object> c = new LinkedHashMap<>();
            c.put("code", p.name());
            c.put("label", ProfessionClassifier.label(p));
            return c;
        }).toList();
        matrix.put("columns", columns);

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Level level : DEGREE_LEVELS) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("levelCode", level.name());
            row.put("levelLabel", DegreeLevelNormalizer.label(level));
            Map<String, Integer> counts = new LinkedHashMap<>();
            int total = 0;
            for (Profession p : TARGET_PROFESSIONS) {
                int n = (int) data.rows.stream()
                        .filter(r -> r.profession == p && r.level == level)
                        .count();
                counts.put(p.name(), n);
                total += n;
            }
            row.put("counts", counts);
            row.put("total", total);
            rows.add(row);
        }
        matrix.put("rows", rows);

        Map<String, Integer> columnTotals = new LinkedHashMap<>();
        int grand = 0;
        for (Profession p : TARGET_PROFESSIONS) {
            int n = (int) data.rows.stream().filter(r -> r.profession == p).count();
            columnTotals.put(p.name(), n);
            grand += n;
        }
        matrix.put("columnTotals", columnTotals);
        matrix.put("grandTotal", grand);
        return matrix;
    }

    private List<Map<String, Object>> degreeLevelBreakdown(List<EmployeeRow> subset) {
        Map<Level, Long> counts = subset.stream()
                .collect(Collectors.groupingBy(r -> r.level, Collectors.counting()));
        List<Map<String, Object>> out = new ArrayList<>();
        for (Level level : DEGREE_LEVELS) {
            long n = counts.getOrDefault(level, 0L);
            if (n == 0 && level != Level.MISSING && level != Level.DAI_HOC && level != Level.CAO_DANG
                    && level != Level.TRUNG_CAP) {
                // vẫn hiện các mức phổ biến; ẩn mức cao nếu = 0 để gọn — thực ra user muốn đầy đủ: luôn hiện
            }
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("code", level.name());
            m.put("label", DegreeLevelNormalizer.label(level));
            m.put("count", n);
            m.put("percent", pct(n, subset.size()));
            out.add(m);
        }
        return out;
    }

    private List<Map<String, Object>> rawDegreeBreakdown(List<EmployeeRow> subset) {
        Map<String, Long> counts = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        for (EmployeeRow r : subset) {
            String key = r.degreeRaw.isBlank() ? "(Chưa cập nhật)" : r.degreeRaw;
            counts.merge(key, 1L, Long::sum);
        }
        return counts.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed()
                        .thenComparing(Map.Entry.comparingByKey(String.CASE_INSENSITIVE_ORDER)))
                .map(e -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("degree", e.getKey());
                    m.put("count", e.getValue());
                    m.put("percent", pct(e.getValue(), subset.size()));
                    return m;
                })
                .toList();
    }

    private List<Map<String, Object>> departmentBreakdown(List<EmployeeRow> subset) {
        Map<String, List<EmployeeRow>> byDept = subset.stream()
                .collect(Collectors.groupingBy(
                        r -> r.departmentName == null || r.departmentName.isBlank() ? "(Chưa có khoa)" : r.departmentName,
                        LinkedHashMap::new,
                        Collectors.toList()));
        List<Map<String, Object>> out = new ArrayList<>();
        byDept.entrySet().stream()
                .sorted(Comparator
                        .comparingInt((Map.Entry<String, List<EmployeeRow>> e) -> -e.getValue().size())
                        .thenComparing(Map.Entry::getKey, String.CASE_INSENSITIVE_ORDER))
                .forEach(e -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("departmentName", e.getKey());
                    m.put("count", e.getValue().size());
                    m.put("byDegreeLevel", degreeLevelBreakdown(e.getValue()));
                    out.add(m);
                });
        return out;
    }

    private List<Map<String, Object>> statusBreakdown(List<EmployeeRow> subset) {
        Map<String, Long> counts = subset.stream()
                .collect(Collectors.groupingBy(
                        r -> r.status == null || r.status.isBlank() ? "UNKNOWN" : r.status,
                        LinkedHashMap::new,
                        Collectors.counting()));
        List<Map<String, Object>> out = new ArrayList<>();
        counts.forEach((status, n) -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("status", status);
            m.put("label", statusLabel(status));
            m.put("count", n);
            m.put("percent", pct(n, subset.size()));
            out.add(m);
        });
        return out;
    }

    private Map<String, Object> toDetailMap(EmployeeRow r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("employeeId", r.employeeId);
        m.put("employeeCode", r.employeeCode);
        m.put("fullName", r.fullName);
        m.put("departmentId", r.departmentId);
        m.put("departmentName", r.departmentName);
        m.put("positionTitle", r.positionTitle);
        m.put("status", r.status);
        m.put("statusLabel", statusLabel(r.status));
        m.put("professionCode", r.profession.name());
        m.put("professionLabel", ProfessionClassifier.label(r.profession));
        m.put("degreeRaw", r.degreeRaw.isBlank() ? null : r.degreeRaw);
        m.put("degreeLevelCode", r.level.name());
        m.put("degreeLevelLabel", DegreeLevelNormalizer.label(r.level));
        return m;
    }

    private static Double pct(long numerator, long denominator) {
        if (denominator <= 0) {
            return 0.0;
        }
        return BigDecimal.valueOf(numerator * 100.0 / denominator)
                .setScale(1, RoundingMode.HALF_UP)
                .doubleValue();
    }

    private static String statusLabel(String status) {
        return switch (status) {
            case "ACTIVE" -> "Chính thức";
            case "PROBATION" -> "Thử việc";
            case "INTERN" -> "Thực tập";
            case "ON_LEAVE" -> "Tạm nghỉ";
            default -> status != null ? status : "—";
        };
    }

    /* ===================== Excel ===================== */

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
            sheet.setMargin(Sheet.TopMargin, 0.5);
            sheet.setMargin(Sheet.BottomMargin, 0.5);
            Footer footer = sheet.getFooter();
            footer.setLeft("Bệnh viện Minh An — Trình độ chuyên môn");
            footer.setCenter("&A");
            footer.setRight("Trang &P / &N");
        }
    }

    private int writeFormalHeader(Sheet sheet, Styles s, int lastCol, String subtitle) {
        int r = 0;
        Row org = sheet.createRow(r++);
        org.setHeightInPoints(20f);
        Cell orgCell = org.createCell(0);
        orgCell.setCellValue("BỆNH VIỆN MINH AN");
        orgCell.setCellStyle(s.orgName);
        sheet.addMergedRegion(new CellRangeAddress(0, 0, 0, lastCol));

        Row unit = sheet.createRow(r++);
        unit.setHeightInPoints(17f);
        Cell unitCell = unit.createCell(0);
        unitCell.setCellValue("PHÒNG TỔ CHỨC CÁN BỘ — QUẢN TRỊ NHÂN SỰ");
        unitCell.setCellStyle(s.orgSub);
        sheet.addMergedRegion(new CellRangeAddress(1, 1, 0, lastCol));

        Row title = sheet.createRow(r++);
        title.setHeightInPoints(24f);
        Cell titleCell = title.createCell(0);
        titleCell.setCellValue("BÁO CÁO TRÌNH ĐỘ CHUYÊN MÔN THEO ĐỐI TƯỢNG");
        titleCell.setCellStyle(s.reportTitle);
        sheet.addMergedRegion(new CellRangeAddress(2, 2, 0, lastCol));

        Row sub = sheet.createRow(r++);
        sub.setHeightInPoints(16f);
        Cell subCell = sub.createCell(0);
        subCell.setCellValue(subtitle);
        subCell.setCellStyle(s.reportSub);
        sheet.addMergedRegion(new CellRangeAddress(3, 3, 0, lastCol));

        Row divider = sheet.createRow(r++);
        divider.setHeightInPoints(6f);
        for (int i = 0; i <= lastCol; i++) {
            Cell c = divider.createCell(i);
            c.setCellStyle(s.divider);
        }
        return r;
    }

    private int writeSectionBanner(Sheet sheet, Styles s, int r, int lastCol, String text) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(22f);
        Cell c = row.createCell(0);
        c.setCellValue(text);
        c.setCellStyle(s.section);
        for (int i = 1; i <= lastCol; i++) {
            row.createCell(i).setCellStyle(s.section);
        }
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    private void writeOverviewSheet(XSSFWorkbook wb, Styles s, ReportData data) {
        Sheet sheet = wb.createSheet("Tổng quan");
        sheet.setDisplayGridlines(false);
        int lastCol = 5;
        long missing = data.rows.stream().filter(x -> x.level == Level.MISSING).count();
        long withDegree = data.rows.size() - missing;
        String subtitle = "Xuất lúc " + TS.format(Instant.now())
                + "  ·  Chỉ nhân sự chưa nghỉ việc  ·  Nguồn: Trình độ / bằng cấp trên hồ sơ";

        int r = writeFormalHeader(sheet, s, lastCol, subtitle);
        r++;
        r = writeSectionBanner(sheet, s, r, lastCol, "I. CHỈ SỐ TỔNG HỢP");
        r++;

        Row kpiLabel = sheet.createRow(r++);
        kpiLabel.setHeightInPoints(18f);
        String[] kpiLabels = {
                "Nhân sự toàn viện", "Trong 6 đối tượng", "Có bằng cấp",
                "Chưa cập nhật", "Tỷ lệ cập nhật (%)", "Nhóm có dữ liệu"
        };
        long groupsWithData = TARGET_PROFESSIONS.stream()
                .filter(p -> data.rows.stream().anyMatch(x -> x.profession == p))
                .count();
        double updatePct = data.rows.isEmpty() ? 0
                : BigDecimal.valueOf(withDegree * 100.0 / data.rows.size())
                .setScale(1, RoundingMode.HALF_UP).doubleValue();
        String[] kpiValues = {
                String.valueOf(data.allActive.size()),
                String.valueOf(data.rows.size()),
                String.valueOf(withDegree),
                String.valueOf(missing),
                String.valueOf(updatePct),
                String.valueOf(groupsWithData)
        };
        for (int i = 0; i < kpiLabels.length; i++) {
            Cell c = kpiLabel.createCell(i);
            c.setCellValue(kpiLabels[i]);
            c.setCellStyle(s.kpiLabel);
        }
        Row kpiValue = sheet.createRow(r++);
        kpiValue.setHeightInPoints(26f);
        for (int i = 0; i < kpiValues.length; i++) {
            Cell c = kpiValue.createCell(i);
            c.setCellValue(kpiValues[i]);
            c.setCellStyle(s.kpiValue);
        }

        r++;
        r = writeSectionBanner(sheet, s, r, lastCol, "II. TỔNG HỢP THEO ĐỐI TƯỢNG");
        r++;

        int headerRow = r;
        Row head = sheet.createRow(r++);
        head.setHeightInPoints(26f);
        String[] headers = {
                "Đối tượng", "Tổng số", "Có bằng cấp", "Chưa cập nhật", "% chưa cập nhật", "Trình độ phổ biến nhất"
        };
        for (int i = 0; i < headers.length; i++) {
            Cell c = head.createCell(i);
            c.setCellValue(headers[i]);
            c.setCellStyle(s.header);
        }

        int stt = 0;
        for (Profession p : TARGET_PROFESSIONS) {
            List<EmployeeRow> subset = data.rows.stream().filter(x -> x.profession == p).toList();
            long miss = subset.stream().filter(x -> x.level == Level.MISSING).count();
            String topDegree = subset.stream()
                    .filter(x -> x.level != Level.MISSING)
                    .collect(Collectors.groupingBy(x -> x.level, Collectors.counting()))
                    .entrySet().stream()
                    .max(Map.Entry.comparingByValue())
                    .map(e -> DegreeLevelNormalizer.label(e.getKey()) + " (" + e.getValue() + ")")
                    .orElse("—");
            Row row = sheet.createRow(r++);
            row.setHeightInPoints(20f);
            boolean zebra = (++stt) % 2 == 0;
            Object[] vals = {
                    ProfessionClassifier.label(p),
                    subset.size(),
                    subset.size() - miss,
                    miss,
                    pct(miss, subset.size()),
                    topDegree
            };
            for (int i = 0; i < vals.length; i++) {
                Cell c = row.createCell(i);
                if (vals[i] instanceof Number n) {
                    c.setCellValue(n.doubleValue());
                    c.setCellStyle(zebra ? s.centerZebra : s.center);
                } else {
                    c.setCellValue(String.valueOf(vals[i]));
                    c.setCellStyle(i == 0
                            ? (zebra ? s.textZebra : s.text)
                            : (zebra ? s.centerZebra : s.center));
                }
            }
        }

        r += 2;
        Row note = sheet.createRow(r);
        note.setHeightInPoints(32f);
        Cell noteCell = note.createCell(0);
        noteCell.setCellValue("Ghi chú: Đối tượng được phân loại theo chức danh; trình độ chuẩn hoá từ trường «Trình độ / bằng cấp» trên hồ sơ nhân lực.");
        noteCell.setCellStyle(s.footnote);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));

        sheet.createFreezePane(0, headerRow + 1);
        sheet.setRepeatingRows(new CellRangeAddress(headerRow, headerRow, 0, lastCol));
        int[] widths = {5200, 3200, 3600, 3600, 4000, 9000};
        for (int i = 0; i < widths.length; i++) {
            sheet.setColumnWidth(i, widths[i]);
        }
    }

    private void writeMatrixSheet(XSSFWorkbook wb, Styles s, ReportData data) {
        Sheet sheet = wb.createSheet("Ma trận trình độ");
        sheet.setDisplayGridlines(false);
        int lastCol = TARGET_PROFESSIONS.size() + 1;
        String subtitle = "Xuất lúc " + TS.format(Instant.now()) + "  ·  Số lượng nhân sự theo trình độ chuẩn hoá × đối tượng";
        int r = writeFormalHeader(sheet, s, lastCol, subtitle);
        r++;
        r = writeSectionBanner(sheet, s, r, lastCol, "MA TRẬN TRÌNH ĐỘ CHUYÊN MÔN");
        r++;

        int headerRow = r;
        Row head = sheet.createRow(r++);
        head.setHeightInPoints(26f);
        Cell h0 = head.createCell(0);
        h0.setCellValue("Trình độ \\ Đối tượng");
        h0.setCellStyle(s.header);
        int col = 1;
        for (Profession p : TARGET_PROFESSIONS) {
            Cell c = head.createCell(col++);
            c.setCellValue(ProfessionClassifier.label(p));
            c.setCellStyle(s.header);
        }
        Cell ht = head.createCell(col);
        ht.setCellValue("Tổng");
        ht.setCellStyle(s.header);

        int rowIdx = 0;
        for (Level level : DEGREE_LEVELS) {
            Row row = sheet.createRow(r++);
            row.setHeightInPoints(20f);
            boolean zebra = (++rowIdx) % 2 == 0;
            Cell lc = row.createCell(0);
            lc.setCellValue(DegreeLevelNormalizer.label(level));
            lc.setCellStyle(zebra ? s.textZebra : s.textBold);
            int cIdx = 1;
            int total = 0;
            for (Profession p : TARGET_PROFESSIONS) {
                int n = (int) data.rows.stream().filter(x -> x.profession == p && x.level == level).count();
                Cell c = row.createCell(cIdx++);
                c.setCellValue(n);
                c.setCellStyle(zebra ? s.centerZebra : s.center);
                total += n;
            }
            Cell t = row.createCell(cIdx);
            t.setCellValue(total);
            t.setCellStyle(zebra ? s.textBoldZebra : s.textBold);
        }

        Row totalRow = sheet.createRow(r);
        totalRow.setHeightInPoints(22f);
        Cell tl = totalRow.createCell(0);
        tl.setCellValue("Tổng");
        tl.setCellStyle(s.header);
        int cIdx = 1;
        int grand = 0;
        for (Profession p : TARGET_PROFESSIONS) {
            int n = (int) data.rows.stream().filter(x -> x.profession == p).count();
            Cell c = totalRow.createCell(cIdx++);
            c.setCellValue(n);
            c.setCellStyle(s.header);
            grand += n;
        }
        Cell g = totalRow.createCell(cIdx);
        g.setCellValue(grand);
        g.setCellStyle(s.header);

        sheet.createFreezePane(1, headerRow + 1);
        sheet.setColumnWidth(0, 6200);
        for (int i = 1; i <= lastCol; i++) {
            sheet.setColumnWidth(i, 3600);
        }
    }

    private void writeProfessionSheets(XSSFWorkbook wb, Styles s, ReportData data) {
        for (Profession p : TARGET_PROFESSIONS) {
            List<EmployeeRow> subset = data.rows.stream().filter(x -> x.profession == p).toList();
            String name = ProfessionClassifier.label(p);
            if (name.length() > 28) {
                name = name.substring(0, 28);
            }
            Sheet sheet = wb.createSheet(name);
            sheet.setDisplayGridlines(false);
            int lastCol = 4;
            long miss = subset.stream().filter(x -> x.level == Level.MISSING).count();
            String subtitle = ProfessionClassifier.label(p) + " — " + subset.size() + " người"
                    + "  ·  Có bằng cấp " + (subset.size() - miss) + "/" + subset.size()
                    + "  ·  Xuất lúc " + TS.format(Instant.now());

            int r = writeFormalHeader(sheet, s, lastCol, subtitle);
            r++;
            r = writeSectionBanner(sheet, s, r, lastCol, "I. PHÂN BỐ TRÌNH ĐỘ CHUẨN HOÁ");
            r++;

            Row h1 = sheet.createRow(r++);
            h1.setHeightInPoints(24f);
            String[] levelHeaders = {"STT", "Trình độ chuẩn hoá", "Số lượng", "Tỷ lệ %", ""};
            for (int i = 0; i < 4; i++) {
                Cell c = h1.createCell(i);
                c.setCellValue(levelHeaders[i]);
                c.setCellStyle(s.header);
            }
            h1.createCell(4).setCellStyle(s.header);

            int stt = 1;
            for (Map<String, Object> m : degreeLevelBreakdown(subset)) {
                long count = ((Number) m.get("count")).longValue();
                if (count == 0) {
                    continue;
                }
                Row row = sheet.createRow(r++);
                row.setHeightInPoints(19f);
                boolean zebra = stt % 2 == 0;
                Cell c0 = row.createCell(0);
                c0.setCellValue(stt++);
                c0.setCellStyle(zebra ? s.centerZebra : s.center);
                Cell c1 = row.createCell(1);
                c1.setCellValue(String.valueOf(m.get("label")));
                c1.setCellStyle(zebra ? s.textZebra : s.text);
                Cell c2 = row.createCell(2);
                c2.setCellValue(count);
                c2.setCellStyle(zebra ? s.centerZebra : s.center);
                Cell c3 = row.createCell(3);
                c3.setCellValue(((Number) m.get("percent")).doubleValue());
                c3.setCellStyle(zebra ? s.centerZebra : s.center);
            }

            r++;
            r = writeSectionBanner(sheet, s, r, lastCol, "II. BẰNG CẤP NGUYÊN VĂN (TOP)");
            r++;
            Row h2 = sheet.createRow(r++);
            h2.setHeightInPoints(24f);
            String[] rawHeaders = {"STT", "Bằng cấp (nguyên văn)", "Số lượng", "Tỷ lệ %", ""};
            for (int i = 0; i < 4; i++) {
                Cell c = h2.createCell(i);
                c.setCellValue(rawHeaders[i]);
                c.setCellStyle(s.header);
            }
            h2.createCell(4).setCellStyle(s.header);

            stt = 1;
            for (Map<String, Object> m : rawDegreeBreakdown(subset)) {
                if (stt > 25) {
                    break;
                }
                Row row = sheet.createRow(r++);
                row.setHeightInPoints(19f);
                boolean zebra = stt % 2 == 0;
                Cell c0 = row.createCell(0);
                c0.setCellValue(stt++);
                c0.setCellStyle(zebra ? s.centerZebra : s.center);
                Cell c1 = row.createCell(1);
                c1.setCellValue(String.valueOf(m.get("degree")));
                c1.setCellStyle(zebra ? s.textZebra : s.text);
                Cell c2 = row.createCell(2);
                c2.setCellValue(((Number) m.get("count")).doubleValue());
                c2.setCellStyle(zebra ? s.centerZebra : s.center);
                Cell c3 = row.createCell(3);
                c3.setCellValue(((Number) m.get("percent")).doubleValue());
                c3.setCellStyle(zebra ? s.centerZebra : s.center);
            }

            r++;
            r = writeSectionBanner(sheet, s, r, lastCol, "III. THEO KHOA / PHÒNG");
            r++;
            Row h3 = sheet.createRow(r++);
            h3.setHeightInPoints(24f);
            String[] deptHeaders = {"STT", "Khoa / phòng", "Số lượng", "Trình độ nổi bật", "Tỷ lệ %"};
            for (int i = 0; i < deptHeaders.length; i++) {
                Cell c = h3.createCell(i);
                c.setCellValue(deptHeaders[i]);
                c.setCellStyle(s.header);
            }

            stt = 1;
            for (Map<String, Object> m : departmentBreakdown(subset)) {
                @SuppressWarnings("unchecked")
                List<Map<String, Object>> levels = (List<Map<String, Object>>) m.get("byDegreeLevel");
                String top = levels == null ? "—" : levels.stream()
                        .filter(x -> ((Number) x.get("count")).longValue() > 0)
                        .max(Comparator.comparingLong(x -> ((Number) x.get("count")).longValue()))
                        .map(x -> x.get("label") + " (" + x.get("count") + ")")
                        .orElse("—");
                long count = ((Number) m.get("count")).longValue();
                Row row = sheet.createRow(r++);
                row.setHeightInPoints(19f);
                boolean zebra = stt % 2 == 0;
                Cell c0 = row.createCell(0);
                c0.setCellValue(stt++);
                c0.setCellStyle(zebra ? s.centerZebra : s.center);
                Cell c1 = row.createCell(1);
                c1.setCellValue(String.valueOf(m.get("departmentName")));
                c1.setCellStyle(zebra ? s.textZebra : s.text);
                Cell c2 = row.createCell(2);
                c2.setCellValue(count);
                c2.setCellStyle(zebra ? s.centerZebra : s.center);
                Cell c3 = row.createCell(3);
                c3.setCellValue(top);
                c3.setCellStyle(zebra ? s.textZebra : s.text);
                Cell c4 = row.createCell(4);
                c4.setCellValue(pct(count, subset.size()));
                c4.setCellStyle(zebra ? s.centerZebra : s.center);
            }

            sheet.setColumnWidth(0, 2200);
            sheet.setColumnWidth(1, 11000);
            sheet.setColumnWidth(2, 3600);
            sheet.setColumnWidth(3, 7200);
            sheet.setColumnWidth(4, 3600);
        }
    }

    private void writeDetailSheet(XSSFWorkbook wb, Styles s, ReportData data) {
        Sheet sheet = wb.createSheet("Chi tiết nhân sự");
        sheet.setDisplayGridlines(false);
        String[] headers = {
                "STT", "Mã NV", "Họ và tên", "Khoa/phòng", "Chức danh",
                "Đối tượng", "Trạng thái", "Bằng cấp (nguyên văn)", "Trình độ chuẩn hoá"
        };
        int lastCol = headers.length - 1;
        String subtitle = "Danh sách " + data.rows.size() + " nhân sự trong phạm vi báo cáo  ·  Xuất lúc " + TS.format(Instant.now());
        int r = writeFormalHeader(sheet, s, lastCol, subtitle);
        r++;
        r = writeSectionBanner(sheet, s, r, lastCol, "DANH SÁCH NHÂN SỰ");
        r++;

        int headerRow = r;
        Row head = sheet.createRow(r++);
        head.setHeightInPoints(26f);
        for (int i = 0; i < headers.length; i++) {
            Cell c = head.createCell(i);
            c.setCellValue(headers[i]);
            c.setCellStyle(s.header);
        }

        int stt = 1;
        for (EmployeeRow item : data.rows) {
            Row row = sheet.createRow(r++);
            row.setHeightInPoints(19f);
            boolean zebra = stt % 2 == 0;
            Object[] vals = {
                    stt++,
                    item.employeeCode != null ? item.employeeCode : "",
                    item.fullName,
                    item.departmentName,
                    item.positionTitle,
                    ProfessionClassifier.label(item.profession),
                    statusLabel(item.status),
                    item.degreeRaw.isBlank() ? "(Chưa cập nhật)" : item.degreeRaw,
                    DegreeLevelNormalizer.label(item.level)
            };
            for (int i = 0; i < vals.length; i++) {
                Cell c = row.createCell(i);
                if (vals[i] instanceof Number n) {
                    c.setCellValue(n.doubleValue());
                    c.setCellStyle(zebra ? s.centerZebra : s.center);
                } else {
                    c.setCellValue(String.valueOf(vals[i]));
                    boolean center = i == 1 || i == 5 || i == 6 || i == 8;
                    c.setCellStyle(center
                            ? (zebra ? s.centerZebra : s.center)
                            : (zebra ? s.textZebra : s.text));
                }
            }
        }

        sheet.createFreezePane(0, headerRow + 1);
        sheet.setRepeatingRows(new CellRangeAddress(headerRow, headerRow, 0, lastCol));
        int[] widths = {2200, 4200, 7200, 9000, 5200, 4200, 3600, 7200, 5200};
        for (int i = 0; i < widths.length; i++) {
            sheet.setColumnWidth(i, widths[i]);
        }
    }

    private static class Styles {
        final XSSFCellStyle orgName;
        final XSSFCellStyle orgSub;
        final XSSFCellStyle reportTitle;
        final XSSFCellStyle reportSub;
        final XSSFCellStyle divider;
        final XSSFCellStyle section;
        final XSSFCellStyle header;
        final XSSFCellStyle kpiLabel;
        final XSSFCellStyle kpiValue;
        final XSSFCellStyle text;
        final XSSFCellStyle textZebra;
        final XSSFCellStyle textBold;
        final XSSFCellStyle textBoldZebra;
        final XSSFCellStyle center;
        final XSSFCellStyle centerZebra;
        final XSSFCellStyle footnote;

        Styles(XSSFWorkbook wb) {
            orgName = centerNoBorder(wb, font(wb, 13, true, INK));
            orgSub = centerNoBorder(wb, font(wb, 11, true, BRAND));
            reportTitle = centerNoBorder(wb, font(wb, 14, true, BRAND_DARK));
            reportSub = centerNoBorder(wb, font(wb, 9, false, MUTED));
            divider = divider(wb);
            section = fill(wb, font(wb, 11, true, BRAND_DARK), BRAND_LIGHT, HorizontalAlignment.LEFT);
            header = fill(wb, font(wb, 10, true, HEADER_TEXT), BRAND, HorizontalAlignment.CENTER);
            kpiLabel = fill(wb, font(wb, 9, true, MUTED), "F1F5F9", HorizontalAlignment.CENTER);
            kpiValue = fill(wb, font(wb, 12, true, BRAND), "F0FDFA", HorizontalAlignment.CENTER);
            text = bordered(wb, font(wb, 10, false, INK), HorizontalAlignment.LEFT, null);
            textZebra = bordered(wb, font(wb, 10, false, INK), HorizontalAlignment.LEFT, ZEBRA);
            textBold = bordered(wb, font(wb, 10, true, INK), HorizontalAlignment.LEFT, null);
            textBoldZebra = bordered(wb, font(wb, 10, true, INK), HorizontalAlignment.LEFT, ZEBRA);
            center = bordered(wb, font(wb, 10, false, INK), HorizontalAlignment.CENTER, null);
            centerZebra = bordered(wb, font(wb, 10, false, INK), HorizontalAlignment.CENTER, ZEBRA);
            footnote = leftNoBorder(wb, font(wb, 9, false, MUTED));
        }

        private static XSSFFont font(XSSFWorkbook wb, int size, boolean bold, String hex) {
            XSSFFont f = wb.createFont();
            f.setFontName(FONT);
            f.setFontHeightInPoints((short) size);
            f.setBold(bold);
            f.setColor(rgb(hex));
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
            st.setBorderBottom(BorderStyle.MEDIUM);
            st.setBottomBorderColor(rgb(BRAND));
            return st;
        }

        private static XSSFCellStyle fill(
                XSSFWorkbook wb, XSSFFont font, String bg, HorizontalAlignment align) {
            return bordered(wb, font, align, bg);
        }

        private static XSSFCellStyle bordered(
                XSSFWorkbook wb, XSSFFont font, HorizontalAlignment align, String bg) {
            XSSFCellStyle st = wb.createCellStyle();
            st.setFont(font);
            st.setAlignment(align);
            st.setVerticalAlignment(VerticalAlignment.CENTER);
            st.setWrapText(true);
            XSSFColor border = rgb(BORDER);
            st.setBorderTop(BorderStyle.THIN);
            st.setBorderBottom(BorderStyle.THIN);
            st.setBorderLeft(BorderStyle.THIN);
            st.setBorderRight(BorderStyle.THIN);
            st.setTopBorderColor(border);
            st.setBottomBorderColor(border);
            st.setLeftBorderColor(border);
            st.setRightBorderColor(border);
            if (bg != null) {
                st.setFillForegroundColor(rgb(bg));
                st.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            }
            return st;
        }

        private static XSSFColor rgb(String hex) {
            byte[] b = new byte[3];
            b[0] = (byte) Integer.parseInt(hex.substring(0, 2), 16);
            b[1] = (byte) Integer.parseInt(hex.substring(2, 4), 16);
            b[2] = (byte) Integer.parseInt(hex.substring(4, 6), 16);
            return new XSSFColor(b, null);
        }
    }

    private record EmployeeRow(
            Long employeeId,
            String employeeCode,
            String fullName,
            String departmentName,
            Long departmentId,
            String positionTitle,
            String status,
            Profession profession,
            String degreeRaw,
            Level level,
            PracticeCert cert
    ) {}

    private static String blankToEmpty(String v) {
        return v == null ? "" : v.trim();
    }

    /* ===================== Chứng chỉ hành nghề ===================== */

    /**
     * Trạng thái chứng chỉ hành nghề suy từ hồ sơ nhân lực.
     *
     * Luật Khám bệnh, chữa bệnh 2023 (hiệu lực 01/01/2024): giấy phép hành nghề
     * cấp từ 2024 có thời hạn 5 năm; chứng chỉ cấp trước đó không ghi thời hạn.
     * Báo cáo chỉ suy ngày hết hạn cho nhóm cấp từ 2024, nhóm cũ ghi nhận là
     * "không thời hạn" để tránh cảnh báo sai.
     */
    enum CertStatus {
        MISSING("Chưa có CCHN"),
        NO_DATE("Có CCHN, thiếu ngày cấp"),
        UNLIMITED("CCHN cấp trước 2024"),
        VALID("Giấy phép còn hạn"),
        EXPIRING_SOON("Sắp hết hạn (≤ 6 tháng)"),
        EXPIRED("Đã hết hạn");

        final String label;

        CertStatus(String label) {
            this.label = label;
        }
    }

    private static final LocalDate NEW_LAW_EFFECTIVE = LocalDate.of(2024, 1, 1);
    private static final int LICENSE_VALID_YEARS = 5;
    private static final int EXPIRING_SOON_DAYS = 180;
    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final Pattern DATE_DMY = Pattern.compile("(\\d{1,2})[/.\\-](\\d{1,2})[/.\\-](\\d{4})");
    private static final Pattern DATE_ISO = Pattern.compile("(\\d{4})-(\\d{2})-(\\d{2})");
    private static final Pattern DATE_MY = Pattern.compile("(?<![\\d/])(\\d{1,2})/(\\d{4})(?!\\d)");
    private static final Pattern DATE_Y = Pattern.compile("(?<!\\d)((?:19|20)\\d{2})(?!\\d)");

    private record PracticeCert(
            String number,
            String dateRaw,
            LocalDate issueDate,
            LocalDate expiryDate,
            String scope,
            CertStatus status
    ) {
        static PracticeCert of(String number, String dateRaw, String scope, LocalDate today) {
            if (number.isBlank()) {
                return new PracticeCert("", dateRaw, null, null, scope, CertStatus.MISSING);
            }
            LocalDate issue = parseIssueDate(dateRaw);
            if (issue == null) {
                return new PracticeCert(number, dateRaw, null, null, scope, CertStatus.NO_DATE);
            }
            if (issue.isBefore(NEW_LAW_EFFECTIVE)) {
                return new PracticeCert(number, dateRaw, issue, null, scope, CertStatus.UNLIMITED);
            }
            LocalDate expiry = issue.plusYears(LICENSE_VALID_YEARS);
            CertStatus status;
            if (!expiry.isAfter(today)) {
                status = CertStatus.EXPIRED;
            } else if (ChronoUnit.DAYS.between(today, expiry) <= EXPIRING_SOON_DAYS) {
                status = CertStatus.EXPIRING_SOON;
            } else {
                status = CertStatus.VALID;
            }
            return new PracticeCert(number, dateRaw, issue, expiry, scope, status);
        }

        boolean present() {
            return status != CertStatus.MISSING;
        }

        boolean needsAttention() {
            return status == CertStatus.MISSING
                    || status == CertStatus.NO_DATE
                    || status == CertStatus.EXPIRING_SOON
                    || status == CertStatus.EXPIRED;
        }
    }

    /**
     * Ngày cấp trên hồ sơ là chuỗi tự do (dd/MM/yyyy, yyyy-MM-dd, MM/yyyy,
     * chỉ năm, hoặc kèm ghi chú). Bắt mốc đầu tiên nhận ra được, sai thì null.
     */
    static LocalDate parseIssueDate(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String text = raw.trim();
        Matcher m = DATE_DMY.matcher(text);
        if (m.find()) {
            try {
                return LocalDate.of(Integer.parseInt(m.group(3)), Integer.parseInt(m.group(2)),
                        Integer.parseInt(m.group(1)));
            } catch (java.time.DateTimeException ignored) {
                // Ghi đủ ngày/tháng/năm nhưng sai (31/02): coi là thiếu ngày cấp để hồ sơ sửa lại.
                return null;
            }
        }
        m = DATE_ISO.matcher(text);
        if (m.find()) {
            try {
                return LocalDate.of(Integer.parseInt(m.group(1)), Integer.parseInt(m.group(2)),
                        Integer.parseInt(m.group(3)));
            } catch (java.time.DateTimeException ignored) {
                return null;
            }
        }
        m = DATE_MY.matcher(text);
        if (m.find()) {
            int month = Integer.parseInt(m.group(1));
            if (month >= 1 && month <= 12) {
                return LocalDate.of(Integer.parseInt(m.group(2)), month, 1);
            }
        }
        m = DATE_Y.matcher(text);
        if (m.find()) {
            return LocalDate.of(Integer.parseInt(m.group(1)), 1, 1);
        }
        return null;
    }

    private Map<String, Object> buildPracticeCertificateBlock(ReportData data) {
        List<EmployeeRow> rows = data.rows;
        long withCert = rows.stream().filter(r -> r.cert.present()).count();
        long missing = rows.size() - withCert;
        Map<CertStatus, Long> byStatus = rows.stream()
                .collect(Collectors.groupingBy(r -> r.cert.status, Collectors.counting()));

        Map<String, Object> out = new LinkedHashMap<>();
        Map<String, Object> kpi = new LinkedHashMap<>();
        kpi.put("total", rows.size());
        kpi.put("withCert", withCert);
        kpi.put("missing", missing);
        kpi.put("coveragePercent", pct(withCert, rows.size()));
        kpi.put("noDate", byStatus.getOrDefault(CertStatus.NO_DATE, 0L));
        kpi.put("unlimited", byStatus.getOrDefault(CertStatus.UNLIMITED, 0L));
        kpi.put("valid", byStatus.getOrDefault(CertStatus.VALID, 0L));
        kpi.put("expiringSoon", byStatus.getOrDefault(CertStatus.EXPIRING_SOON, 0L));
        kpi.put("expired", byStatus.getOrDefault(CertStatus.EXPIRED, 0L));
        kpi.put("needsAttention", rows.stream().filter(r -> r.cert.needsAttention()).count());
        out.put("kpi", kpi);

        out.put("statusOrder", Arrays.stream(CertStatus.values()).map(Enum::name).toList());
        out.put("statusLabels", Arrays.stream(CertStatus.values())
                .collect(Collectors.toMap(Enum::name, c -> c.label, (a, b) -> a, LinkedHashMap::new)));
        out.put("byStatus", Arrays.stream(CertStatus.values()).map(st -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("code", st.name());
            m.put("label", st.label);
            long n = byStatus.getOrDefault(st, 0L);
            m.put("count", n);
            m.put("percent", pct(n, rows.size()));
            return m;
        }).toList());

        List<Map<String, Object>> byProfession = new ArrayList<>();
        for (Profession p : TARGET_PROFESSIONS) {
            List<EmployeeRow> subset = rows.stream().filter(r -> r.profession == p).toList();
            long have = subset.stream().filter(r -> r.cert.present()).count();
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("code", p.name());
            m.put("label", ProfessionClassifier.label(p));
            m.put("total", subset.size());
            m.put("withCert", have);
            m.put("missing", subset.size() - have);
            m.put("coveragePercent", pct(have, subset.size()));
            m.put("expiringSoon", subset.stream().filter(r -> r.cert.status == CertStatus.EXPIRING_SOON).count());
            m.put("expired", subset.stream().filter(r -> r.cert.status == CertStatus.EXPIRED).count());
            m.put("noDate", subset.stream().filter(r -> r.cert.status == CertStatus.NO_DATE).count());
            byProfession.add(m);
        }
        out.put("byProfession", byProfession);

        Map<String, List<EmployeeRow>> byDept = rows.stream().collect(Collectors.groupingBy(
                r -> r.departmentName == null || r.departmentName.isBlank() ? "(Chưa có khoa)" : r.departmentName,
                LinkedHashMap::new, Collectors.toList()));
        List<Map<String, Object>> byDepartment = byDept.entrySet().stream()
                .map(e -> {
                    long have = e.getValue().stream().filter(r -> r.cert.present()).count();
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("departmentName", e.getKey());
                    m.put("total", e.getValue().size());
                    m.put("withCert", have);
                    m.put("missing", e.getValue().size() - have);
                    m.put("coveragePercent", pct(have, e.getValue().size()));
                    m.put("needsAttention", e.getValue().stream().filter(r -> r.cert.needsAttention()).count());
                    return m;
                })
                .sorted(Comparator
                        .comparingLong((Map<String, Object> m) -> -((Number) m.get("missing")).longValue())
                        .thenComparing(m -> String.valueOf(m.get("departmentName")), String.CASE_INSENSITIVE_ORDER))
                .toList();
        out.put("byDepartment", byDepartment);

        Map<Integer, Long> byYear = rows.stream()
                .filter(r -> r.cert.issueDate != null)
                .collect(Collectors.groupingBy(r -> r.cert.issueDate.getYear(), TreeMap::new, Collectors.counting()));
        out.put("byIssueYear", byYear.entrySet().stream().map(e -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("year", e.getKey());
            m.put("count", e.getValue());
            return m;
        }).toList());

        Map<String, Long> byScope = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        rows.stream().filter(r -> r.cert.present() && !r.cert.scope.isBlank())
                .forEach(r -> byScope.merge(r.cert.scope, 1L, Long::sum));
        out.put("byScope", byScope.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed()
                        .thenComparing(Map.Entry.comparingByKey(String.CASE_INSENSITIVE_ORDER)))
                .limit(12)
                .map(e -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("scope", e.getKey());
                    m.put("count", e.getValue());
                    m.put("percent", pct(e.getValue(), withCert));
                    return m;
                })
                .toList());

        List<Map<String, Object>> details = rows.stream()
                .sorted(Comparator
                        .comparingInt((EmployeeRow r) -> certSortOrder(r.cert.status))
                        .thenComparing(r -> r.cert.expiryDate, Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(r -> r.departmentName, String.CASE_INSENSITIVE_ORDER)
                        .thenComparing(r -> r.fullName, String.CASE_INSENSITIVE_ORDER))
                .map(this::toCertDetailMap)
                .toList();
        out.put("details", details);
        return out;
    }

    private static int certSortOrder(CertStatus st) {
        return switch (st) {
            case EXPIRED -> 0;
            case EXPIRING_SOON -> 1;
            case MISSING -> 2;
            case NO_DATE -> 3;
            case VALID -> 4;
            case UNLIMITED -> 5;
        };
    }

    private Map<String, Object> toCertDetailMap(EmployeeRow r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("employeeId", r.employeeId);
        m.put("employeeCode", r.employeeCode);
        m.put("fullName", r.fullName);
        m.put("departmentId", r.departmentId);
        m.put("departmentName", r.departmentName);
        m.put("positionTitle", r.positionTitle);
        m.put("status", r.status);
        m.put("statusLabel", statusLabel(r.status));
        m.put("professionCode", r.profession.name());
        m.put("professionLabel", ProfessionClassifier.label(r.profession));
        m.put("certNumber", r.cert.number.isBlank() ? null : r.cert.number);
        m.put("certDateRaw", r.cert.dateRaw.isBlank() ? null : r.cert.dateRaw);
        m.put("issueDate", r.cert.issueDate != null ? r.cert.issueDate.toString() : null);
        m.put("issueDateLabel", r.cert.issueDate != null ? DMY.format(r.cert.issueDate) : null);
        m.put("expiryDate", r.cert.expiryDate != null ? r.cert.expiryDate.toString() : null);
        m.put("expiryDateLabel", r.cert.expiryDate != null ? DMY.format(r.cert.expiryDate) : null);
        m.put("daysToExpiry", r.cert.expiryDate != null
                ? ChronoUnit.DAYS.between(LocalDate.now(VN), r.cert.expiryDate) : null);
        m.put("scope", r.cert.scope.isBlank() ? null : r.cert.scope);
        m.put("certStatusCode", r.cert.status.name());
        m.put("certStatusLabel", r.cert.status.label);
        m.put("needsAttention", r.cert.needsAttention());
        return m;
    }

    private void writePracticeCertificateSheet(XSSFWorkbook wb, Styles s, ReportData data) {
        Sheet sheet = wb.createSheet("Chứng chỉ hành nghề");
        sheet.setDisplayGridlines(false);
        String[] headers = {
                "STT", "Mã NV", "Họ và tên", "Khoa/phòng", "Đối tượng",
                "Số CCHN", "Ngày cấp", "Hết hạn", "Phạm vi hành nghề", "Trạng thái"
        };
        int lastCol = headers.length - 1;
        List<EmployeeRow> rows = data.rows.stream()
                .sorted(Comparator
                        .comparingInt((EmployeeRow r) -> certSortOrder(r.cert.status))
                        .thenComparing(r -> r.departmentName, String.CASE_INSENSITIVE_ORDER)
                        .thenComparing(r -> r.fullName, String.CASE_INSENSITIVE_ORDER))
                .toList();
        long withCert = rows.stream().filter(r -> r.cert.present()).count();
        String subtitle = "Chứng chỉ / giấy phép hành nghề của " + rows.size() + " nhân sự  ·  Xuất lúc "
                + TS.format(Instant.now());
        int r = writeFormalHeader(sheet, s, lastCol, subtitle);
        r++;
        r = writeSectionBanner(sheet, s, r, lastCol, "I. CHỈ SỐ TỔNG HỢP");
        r++;

        String[] kpiLabels = {
                "Trong phạm vi", "Có CCHN", "Chưa có CCHN", "Tỷ lệ có CCHN (%)",
                "Cấp trước 2024", "Giấy phép còn hạn", "Sắp hết hạn", "Đã hết hạn", "Thiếu ngày cấp"
        };
        Map<CertStatus, Long> byStatus = rows.stream()
                .collect(Collectors.groupingBy(x -> x.cert.status, Collectors.counting()));
        String[] kpiValues = {
                String.valueOf(rows.size()),
                String.valueOf(withCert),
                String.valueOf(rows.size() - withCert),
                String.valueOf(pct(withCert, rows.size())),
                String.valueOf(byStatus.getOrDefault(CertStatus.UNLIMITED, 0L)),
                String.valueOf(byStatus.getOrDefault(CertStatus.VALID, 0L)),
                String.valueOf(byStatus.getOrDefault(CertStatus.EXPIRING_SOON, 0L)),
                String.valueOf(byStatus.getOrDefault(CertStatus.EXPIRED, 0L)),
                String.valueOf(byStatus.getOrDefault(CertStatus.NO_DATE, 0L))
        };
        Row kpiLabel = sheet.createRow(r++);
        kpiLabel.setHeightInPoints(18f);
        for (int i = 0; i < kpiLabels.length; i++) {
            Cell c = kpiLabel.createCell(i);
            c.setCellValue(kpiLabels[i]);
            c.setCellStyle(s.kpiLabel);
        }
        Row kpiValue = sheet.createRow(r++);
        kpiValue.setHeightInPoints(26f);
        for (int i = 0; i < kpiValues.length; i++) {
            Cell c = kpiValue.createCell(i);
            c.setCellValue(kpiValues[i]);
            c.setCellStyle(s.kpiValue);
        }

        r++;
        r = writeSectionBanner(sheet, s, r, lastCol, "II. DANH SÁCH THEO TRẠNG THÁI (ưu tiên hết hạn, sắp hết hạn, chưa có)");
        r++;
        int headerRow = r;
        Row head = sheet.createRow(r++);
        head.setHeightInPoints(26f);
        for (int i = 0; i < headers.length; i++) {
            Cell c = head.createCell(i);
            c.setCellValue(headers[i]);
            c.setCellStyle(s.header);
        }
        int stt = 1;
        for (EmployeeRow item : rows) {
            Row row = sheet.createRow(r++);
            row.setHeightInPoints(19f);
            boolean zebra = stt % 2 == 0;
            Object[] vals = {
                    stt++,
                    item.employeeCode != null ? item.employeeCode : "",
                    item.fullName,
                    item.departmentName,
                    ProfessionClassifier.label(item.profession),
                    item.cert.number.isBlank() ? "(Chưa có)" : item.cert.number,
                    item.cert.issueDate != null ? DMY.format(item.cert.issueDate)
                            : (item.cert.dateRaw.isBlank() ? "" : item.cert.dateRaw),
                    item.cert.expiryDate != null ? DMY.format(item.cert.expiryDate)
                            : (item.cert.status == CertStatus.UNLIMITED ? "Không thời hạn" : ""),
                    item.cert.scope,
                    item.cert.status.label
            };
            for (int i = 0; i < vals.length; i++) {
                Cell c = row.createCell(i);
                if (vals[i] instanceof Number n) {
                    c.setCellValue(n.doubleValue());
                    c.setCellStyle(zebra ? s.centerZebra : s.center);
                } else {
                    c.setCellValue(String.valueOf(vals[i]));
                    boolean center = i == 1 || i == 4 || i == 6 || i == 7 || i == 9;
                    c.setCellStyle(center
                            ? (zebra ? s.centerZebra : s.center)
                            : (zebra ? s.textZebra : s.text));
                }
            }
        }
        sheet.createFreezePane(0, headerRow + 1);
        sheet.setRepeatingRows(new CellRangeAddress(headerRow, headerRow, 0, lastCol));
        int[] widths = {2200, 4200, 7200, 8200, 4200, 5200, 3800, 4200, 9000, 6200};
        for (int i = 0; i < widths.length; i++) {
            sheet.setColumnWidth(i, widths[i]);
        }
    }

    private record ReportData(List<Employee> allActive, List<EmployeeRow> rows) {}
}
