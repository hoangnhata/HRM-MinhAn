package com.minhan.hrm.service;

import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.Sort;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.text.Collator;
import java.text.Normalizer;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@RequiredArgsConstructor
public class WorkforceReportService {

    private static final DateTimeFormatter VN_DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final Collator VI_COLLATOR = Collator.getInstance(Locale.forLanguageTag("vi"));

    /** Cột cố định: bác sĩ đang thử việc / thực tập. */
    static final Category CAT_BAC_SI_THU_VIEC = new Category("BAC_SI_THU_VIEC", "Bác sĩ thử việc");
    /** Cột cố định: nhân viên thử việc / thực tập còn lại (không phải bác sĩ). */
    static final Category CAT_NHAN_VIEN_THU_VIEC = new Category("NHAN_VIEN_THU_VIEC", "Nhân viên thử việc");

    private final EmployeeRepository employeeRepository;
    private final AttendanceRecordRepository attendanceRecordRepository;
    private final DepartmentRepository departmentRepository;

    @Transactional(readOnly = true)
    public Map<String, Object> hospitalReport() {
        List<Employee> employees = employeeRepository.findAllWithDepartment().stream()
                .filter(e -> e.getStatus() != EmployeeStatus.TERMINATED)
                .toList();
        return buildReport("HOSPITAL", LocalDate.now(), employees, Map.of());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> dailyReport(LocalDate date) {
        List<AttendanceRecord> records = attendanceRecordRepository
                .findByWorkDateBetweenWithEmployee(date, date).stream()
                .filter(this::isActuallyWorking)
                .toList();
        Map<Long, AttendanceRecord> byEmployee = new LinkedHashMap<>();
        records.forEach(r -> byEmployee.put(r.getEmployee().getId(), r));
        List<Employee> employees = byEmployee.values().stream().map(AttendanceRecord::getEmployee).toList();
        return buildReport("DAILY", date, employees, byEmployee);
    }

    public byte[] exportHospitalExcel() {
        return exportExcel(hospitalReport());
    }

    public byte[] exportDailyExcel(LocalDate date) {
        return exportExcel(dailyReport(date));
    }

    private Map<String, Object> buildReport(
            String type, LocalDate date,
            List<Employee> employees, Map<Long, AttendanceRecord> attendanceByEmployee) {
        // Cột ma trận = chức vụ thực tế trên hồ sơ nhân viên (không gom nhóm mẫu Excel).
        List<Category> categories = categoriesFromPositions(employees);
        Map<Long, DepartmentAccumulator> departments = new LinkedHashMap<>();
        departmentRepository.findAll(Sort.by(Sort.Direction.ASC, "name")).forEach(department ->
                departments.put(department.getId(), new DepartmentAccumulator(
                        department.getId(), department.getName(), emptyCounts(categories))));
        Map<String, Integer> totals = emptyCounts(categories);
        List<Map<String, Object>> details = new ArrayList<>();

        for (Employee employee : employees) {
            if (employee.getDepartment() == null || employee.getPosition() == null) continue;
            String positionTitle = employee.getPosition().getTitle() == null
                    ? "" : employee.getPosition().getTitle().trim();
            if (positionTitle.isEmpty()) continue;
            String reportLabel = reportPositionLabel(positionTitle);
            Category matrixCat = matrixCategory(employee, reportLabel);
            String category = matrixCat.key();
            DepartmentAccumulator dept = departments.computeIfAbsent(employee.getDepartment().getId(),
                    ignored -> new DepartmentAccumulator(employee.getDepartment().getId(),
                            employee.getDepartment().getName(), emptyCounts(categories)));
            dept.counts().computeIfPresent(category, (k, v) -> v + 1);
            totals.computeIfPresent(category, (k, v) -> v + 1);

            AttendanceRecord record = attendanceByEmployee.get(employee.getId());
            Map<String, Object> detail = new LinkedHashMap<>();
            detail.put("employeeId", employee.getId());
            detail.put("employeeCode", employee.getEmployeeCode());
            detail.put("fullName", employee.getFullName());
            detail.put("departmentId", employee.getDepartment().getId());
            detail.put("departmentName", employee.getDepartment().getName());
            detail.put("positionTitle", positionTitle);
            detail.put("category", category);
            detail.put("categoryLabel", matrixCat.label());
            detail.put("employeeStatus", employee.getStatus().name());
            detail.put("employmentType", employee.getEmploymentType() != null
                    ? employee.getEmploymentType().name() : null);
            detail.put("hireDate", employee.getHireDate() != null ? employee.getHireDate().toString() : null);
            if (record != null) {
                detail.put("attendanceStatus", record.getStatus());
                LocalTime reportIn = reportCheckIn(record);
                LocalTime reportOut = reportCheckOut(record);
                detail.put("checkIn", time(reportIn));
                detail.put("checkOut", time(reportOut));
                detail.put("morningCheckIn", time(record.getMorningCheckIn()));
                detail.put("morningCheckOut", time(record.getMorningCheckOut()));
                detail.put("afternoonCheckIn", time(record.getAfternoonCheckIn()));
                detail.put("afternoonCheckOut", time(record.getAfternoonCheckOut()));
                detail.put("workUnits", nz(record.getMorningWorkUnits()).add(nz(record.getAfternoonWorkUnits())));
                detail.put("lateMinutes", record.getLateMinutes());
            }
            details.add(detail);
        }

        details.sort(Comparator
                .comparing((Map<String, Object> r) -> String.valueOf(r.get("departmentName")), VI_COLLATOR)
                .thenComparing(r -> String.valueOf(r.get("fullName")), VI_COLLATOR));
        List<Map<String, Object>> rows = departments.values().stream().map(d -> {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("departmentId", d.id());
            row.put("departmentName", d.name());
            row.put("counts", d.counts());
            row.put("total", d.counts().values().stream().mapToInt(Integer::intValue).sum());
            return row;
        }).filter(row -> ((Number) row.get("total")).intValue() > 0).toList();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("type", type);
        result.put("reportDate", date.toString());
        result.put("generatedAt", LocalDateTime.now().toString());
        result.put("categories", categories.stream().map(c -> Map.of("key", c.key(), "label", c.label())).toList());
        result.put("rows", rows);
        result.put("totals", totals);
        result.put("grandTotal", totals.values().stream().mapToInt(Integer::intValue).sum());
        result.put("departmentCount", rows.size());
        result.put("details", details);
        return result;
    }

    /**
     * Cột ma trận: chức vụ chính thức + 2 cột thử việc cố định ở cuối
     * (Bác sĩ thử việc, Nhân viên thử việc).
     */
    private static List<Category> categoriesFromPositions(List<Employee> employees) {
        Map<String, String> keyToLabel = new LinkedHashMap<>();
        for (Employee employee : employees) {
            if (isTrialStatus(employee.getStatus())) continue;
            if (employee.getPosition() == null || employee.getPosition().getTitle() == null) continue;
            String title = employee.getPosition().getTitle().trim();
            if (title.isEmpty()) continue;
            String label = reportPositionLabel(title);
            keyToLabel.putIfAbsent(categoryKey(label), label);
        }
        List<Category> categories = new ArrayList<>(keyToLabel.entrySet().stream()
                .sorted(Map.Entry.comparingByValue(VI_COLLATOR))
                .map(e -> new Category(e.getKey(), e.getValue()))
                .toList());
        categories.add(CAT_BAC_SI_THU_VIEC);
        categories.add(CAT_NHAN_VIEN_THU_VIEC);
        return categories;
    }

    /** Cột đếm: thử việc tách khỏi chức vụ chính thức. */
    static Category matrixCategory(Employee employee, String reportLabel) {
        if (isTrialStatus(employee.getStatus())) {
            return isDoctorReportPosition(reportLabel) ? CAT_BAC_SI_THU_VIEC : CAT_NHAN_VIEN_THU_VIEC;
        }
        return new Category(categoryKey(reportLabel), reportLabel);
    }

    static boolean isTrialStatus(EmployeeStatus status) {
        return status == EmployeeStatus.PROBATION || status == EmployeeStatus.INTERN;
    }

    /** Bác sĩ / Bác sĩ RHM / biến thể Bác sỹ… */
    static boolean isDoctorReportPosition(String reportLabel) {
        String folded = fold(reportLabel == null ? "" : reportLabel);
        return "bac si".equals(folded) || folded.startsWith("bac si ");
    }

    /**
     * Chuẩn hóa nhãn chức vụ trên ma trận báo cáo.
     * Gộp biến thể chính tả "Bác sỹ" / "Bác sĩ" → "Bác sĩ".
     */
    static String reportPositionLabel(String title) {
        String trimmed = title == null ? "" : title.trim();
        if (trimmed.isEmpty()) return trimmed;
        String folded = fold(trimmed);
        if ("bac si".equals(folded) || "bac sy".equals(folded)) {
            return "Bác sĩ";
        }
        return trimmed;
    }

    private static String categoryKey(String title) {
        String base = fold(title).replaceAll("[^a-z0-9]+", "_").replaceAll("^_|_$", "");
        if (base.isEmpty()) base = "khac";
        return base.toUpperCase(Locale.ROOT);
    }

    private boolean isActuallyWorking(AttendanceRecord record) {
        if (record.getEmployee() == null || record.getEmployee().getStatus() == EmployeeStatus.TERMINATED) return false;
        // Báo cáo quân số đầu ngày: chỉ cần đã có giờ vào ca sáng là ghi nhận đi làm,
        // không chờ đủ giờ ra hoặc đủ điều kiện cấp công.
        if (record.getMorningCheckIn() != null) return true;
        String status = record.getStatus() == null ? "" : record.getStatus();
        if ("PRESENT".equals(status) || "PARTIAL".equals(status)) return true;
        if ("SEMINAR".equals(status)) {
            return record.getMorningCheckIn() != null || record.getMorningCheckOut() != null
                    || record.getAfternoonCheckIn() != null || record.getAfternoonCheckOut() != null;
        }
        return false;
    }

    /**
     * Báo cáo đi làm: giờ vào = check-in ca sáng (hoặc giờ vào ca thông tầm).
     */
    private static LocalTime reportCheckIn(AttendanceRecord record) {
        return firstNonNull(record.getMorningCheckIn(), record.getCheckIn());
    }

    /**
     * Báo cáo đi làm:
     * - Ca thường: chỉ lấy check-out chiều (afternoonCheckOut). Không lấy morningCheckOut
     *   vì nhân viên hay quẹt lại vân tay buổi sáng → bị hiểu nhầm là giờ ra.
     * - Ca thông tầm: day-in/day-out cũng lưu ở morningCheckIn + afternoonCheckOut.
     * Nếu chưa có giờ ra chiều (hoặc khoảng cách quá gần giờ vào) → null.
     */
    private static LocalTime reportCheckOut(AttendanceRecord record) {
        LocalTime inn = reportCheckIn(record);
        LocalTime out = record.getAfternoonCheckOut();
        if (out == null) {
            // Không dùng morningCheckOut. Legacy checkOut chỉ khi đủ xa giờ vào.
            out = record.getCheckOut();
        }
        if (out == null) return null;
        if (inn != null) {
            if (!out.isAfter(inn)) return null;
            // Quẹt lại trong ~2 giờ sau giờ vào sáng → không phải giờ ra cuối ngày
            if (java.time.Duration.between(inn, out).toMinutes() < 120) return null;
        }
        return out;
    }

    private static LocalTime firstNonNull(LocalTime... values) {
        if (values == null) return null;
        for (LocalTime value : values) {
            if (value != null) return value;
        }
        return null;
    }

    private byte[] exportExcel(Map<String, Object> report) {
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            boolean daily = "DAILY".equals(report.get("type"));
            @SuppressWarnings("unchecked") List<Map<String, String>> categories = (List<Map<String, String>>) report.get("categories");
            @SuppressWarnings("unchecked") List<Map<String, Object>> rows = (List<Map<String, Object>>) report.get("rows");
            @SuppressWarnings("unchecked") List<Map<String, Object>> details = (List<Map<String, Object>>) report.get("details");
            @SuppressWarnings("unchecked") Map<String, Integer> totals = (Map<String, Integer>) report.get("totals");

            ExcelStyles styles = createExcelStyles(wb);

            XSSFSheet matrix = wb.createSheet(daily ? "Nhân lực đi làm" : "Nhân lực toàn viện");
            matrix.setTabColor(color("087F8C"));
            matrix.setDisplayGridlines(false);
            int lastCol = categories.size() + 1;
            String date = LocalDate.parse(String.valueOf(report.get("reportDate"))).format(VN_DATE);
            String reportTitle = daily ? "BÁO CÁO NHÂN LỰC ĐI LÀM HẰNG NGÀY  •  " + date : "BÁO CÁO NHÂN LỰC TOÀN VIỆN";
            mergeAndSet(matrix, 0, 0, 0, lastCol, reportTitle, styles.title());
            matrix.getRow(0).setHeightInPoints(32);
            mergeAndSet(matrix, 1, 1, 0, lastCol,
                    "BỆNH VIỆN ĐA KHOA MINH AN  •  Ngày báo cáo: " + date
                            + "  •  Ngày xuất: " + LocalDate.now().format(VN_DATE), styles.subtitle());
            matrix.getRow(1).setHeightInPoints(24);

            Map.Entry<String, Integer> top = totals.entrySet().stream()
                    .max(Map.Entry.comparingByValue()).orElse(Map.entry("", 0));
            String topLabel = categories.stream().filter(c -> Objects.equals(c.get("key"), top.getKey()))
                    .map(c -> c.get("label")).findFirst().orElse("—");
            String[] kpiLabels = {daily ? "THỰC TẾ CÓ MẶT" : "TỔNG NHÂN LỰC", "KHOA / PHÒNG", "CHỨC VỤ NHIỀU NHẤT", "NGÀY BÁO CÁO"};
            Object[] kpiValues = {report.get("grandTotal"), report.get("departmentCount"), topLabel + " · " + top.getValue(), date};
            int columnCount = lastCol + 1;
            if (columnCount >= kpiLabels.length) {
                for (int i = 0; i < kpiLabels.length; i++) {
                    int from = i * columnCount / kpiLabels.length;
                    int to = ((i + 1) * columnCount / kpiLabels.length) - 1;
                    mergeAndSet(matrix, 2, 2, from, to, kpiLabels[i], styles.kpiLabel());
                    mergeAndSet(matrix, 3, 3, from, to, kpiValues[i], styles.kpiValue());
                }
            } else {
                String summary = kpiLabels[0] + ": " + kpiValues[0]
                        + "  |  " + kpiLabels[1] + ": " + kpiValues[1]
                        + "  |  " + kpiLabels[2] + ": " + kpiValues[2];
                mergeAndSet(matrix, 2, 2, 0, lastCol, summary, styles.kpiLabel());
                mergeAndSet(matrix, 3, 3, 0, lastCol, String.valueOf(kpiValues[3]), styles.kpiValue());
            }
            matrix.getRow(2).setHeightInPoints(20);
            matrix.getRow(3).setHeightInPoints(28);

            Row header = matrix.createRow(5);
            setCell(header, 0, "KHOA / PHÒNG", styles.headerLeft());
            for (int i = 0; i < categories.size(); i++) setCell(header, i + 1, categories.get(i).get("label"), styles.header());
            setCell(header, lastCol, "TỔNG", styles.header());
            header.setHeightInPoints(44);

            int rowIndex = 6;
            for (Map<String, Object> data : rows) {
                Row row = matrix.createRow(rowIndex++);
                boolean even = row.getRowNum() % 2 == 0;
                setCell(row, 0, String.valueOf(data.get("departmentName")), even ? styles.departmentEven() : styles.departmentOdd());
                @SuppressWarnings("unchecked") Map<String, Integer> counts = (Map<String, Integer>) data.get("counts");
                for (int i = 0; i < categories.size(); i++) {
                    int value = counts.getOrDefault(categories.get(i).get("key"), 0);
                    CellStyle cellStyle = value > 0
                            ? (even ? styles.positiveEven() : styles.positiveOdd())
                            : (even ? styles.centerEven() : styles.centerOdd());
                    setCell(row, i + 1, value, cellStyle);
                }
                setCell(row, lastCol, data.get("total"), even ? styles.rowTotalEven() : styles.rowTotalOdd());
                row.setHeightInPoints(23);
            }
            Row total = matrix.createRow(rowIndex);
            setCell(total, 0, "TỔNG CỘNG", styles.total());
            for (int i = 0; i < categories.size(); i++) setCell(total, i + 1, totals.get(categories.get(i).get("key")), styles.total());
            setCell(total, lastCol, report.get("grandTotal"), styles.grandTotal());
            total.setHeightInPoints(26);
            matrix.createFreezePane(1, 6);
            matrix.setAutoFilter(new CellRangeAddress(5, Math.max(5, rowIndex - 1), 0, lastCol));
            matrix.setColumnWidth(0, 36 * 256);
            for (int i = 1; i < lastCol; i++) matrix.setColumnWidth(i, 16 * 256);
            matrix.setColumnWidth(lastCol, 11 * 256);
            matrix.setZoom(85);
            matrix.setRepeatingRows(new CellRangeAddress(0, 5, -1, -1));
            matrix.getPrintSetup().setLandscape(true);
            matrix.setFitToPage(true);
            matrix.getPrintSetup().setFitWidth((short) 1);
            matrix.getPrintSetup().setFitHeight((short) 0);
            configurePrint(matrix, "Báo cáo nhân lực");

            buildDetailSheet(wb, details, daily, date, styles);
            wb.setActiveSheet(0);
            wb.write(out);
            return out.toByteArray();
        } catch (Exception e) {
            throw new IllegalStateException("Không tạo được báo cáo Excel nhân lực", e);
        }
    }

    private static void buildDetailSheet(XSSFWorkbook wb, List<Map<String, Object>> details, boolean daily,
                                         String date, ExcelStyles styles) {
        XSSFSheet sheet = wb.createSheet("Chi tiết nhân viên");
        sheet.setTabColor(color("D99B2B"));
        sheet.setDisplayGridlines(false);
        List<String> headers = new ArrayList<>(List.of("STT", "Mã NV", "Họ và tên", "Khoa/Phòng", "Chức vụ", "Trạng thái NV"));
        if (daily) headers.addAll(List.of("Giờ vào", "Giờ ra", "Công", "Phút muộn/sớm", "Trạng thái công"));
        int lastCol = headers.size() - 1;
        mergeAndSet(sheet, 0, 0, 0, lastCol,
                daily ? "CHI TIẾT NHÂN LỰC ĐI LÀM NGÀY " + date : "CHI TIẾT NHÂN LỰC TOÀN VIỆN", styles.title());
        sheet.getRow(0).setHeightInPoints(30);
        mergeAndSet(sheet, 1, 1, 0, lastCol,
                "BỆNH VIỆN ĐA KHOA MINH AN  •  Tổng số: " + details.size() + " nhân viên", styles.subtitle());
        sheet.getRow(1).setHeightInPoints(23);
        Row header = sheet.createRow(3);
        for (int i = 0; i < headers.size(); i++) setCell(header, i, headers.get(i), i <= 4 ? styles.headerLeft() : styles.header());
        header.setHeightInPoints(32);
        int r = 4;
        int sequence = 1;
        for (Map<String, Object> d : details) {
            Row row = sheet.createRow(r++);
            boolean even = row.getRowNum() % 2 == 0;
            CellStyle left = even ? styles.bodyEven() : styles.bodyOdd();
            CellStyle center = even ? styles.centerEven() : styles.centerOdd();
            CellStyle name = even ? styles.nameEven() : styles.nameOdd();
            int c = 0;
            setCell(row, c++, sequence++, center);
            setCell(row, c++, d.get("employeeCode"), center);
            setCell(row, c++, d.get("fullName"), name);
            setCell(row, c++, d.get("departmentName"), left);
            setCell(row, c++, d.get("positionTitle"), left);
            setCell(row, c++, employeeStatusText(d.get("employeeStatus")), center);
            if (daily) {
                setCell(row, c++, firstNonBlank(d.get("checkIn"), d.get("morningCheckIn")), center);
                setCell(row, c++, d.get("checkOut"), center);
                setCell(row, c++, d.get("workUnits"), even ? styles.decimalEven() : styles.decimalOdd());
                setCell(row, c++, d.get("lateMinutes"), center);
                setCell(row, c, attendanceStatusText(d.get("attendanceStatus")), attendanceStatusStyle(styles, d.get("attendanceStatus")));
            }
            row.setHeightInPoints(22);
        }
        sheet.createFreezePane(0, 4);
        if (!details.isEmpty()) sheet.setAutoFilter(new CellRangeAddress(3, r - 1, 0, lastCol));
        int[] widths = daily ? new int[]{7, 16, 28, 34, 23, 21, 17, 12, 12, 10, 16, 20}
                : new int[]{7, 16, 28, 34, 23, 21, 17};
        for (int i = 0; i < widths.length; i++) sheet.setColumnWidth(i, widths[i] * 256);
        sheet.setZoom(90);
        sheet.setRepeatingRows(new CellRangeAddress(0, 3, -1, -1));
        sheet.getPrintSetup().setLandscape(true);
        sheet.setFitToPage(true);
        sheet.getPrintSetup().setFitWidth((short) 1);
        sheet.getPrintSetup().setFitHeight((short) 0);
        configurePrint(sheet, "Chi tiết nhân lực");
    }

    private static ExcelStyles createExcelStyles(XSSFWorkbook wb) {
        CellStyle bodyOdd = style(wb, "243B3A", "FFFFFF", false, 10, HorizontalAlignment.LEFT, BorderStyle.HAIR);
        CellStyle bodyEven = style(wb, "243B3A", "F4F8F8", false, 10, HorizontalAlignment.LEFT, BorderStyle.HAIR);
        CellStyle centerOdd = style(wb, "365B5A", "FFFFFF", false, 10, HorizontalAlignment.CENTER, BorderStyle.HAIR);
        CellStyle centerEven = style(wb, "365B5A", "F4F8F8", false, 10, HorizontalAlignment.CENTER, BorderStyle.HAIR);
        CellStyle decimalOdd = cloneWithFormat(wb, centerOdd, "0.00");
        CellStyle decimalEven = cloneWithFormat(wb, centerEven, "0.00");
        return new ExcelStyles(
                style(wb, "FFFFFF", "006865", true, 16, HorizontalAlignment.CENTER, BorderStyle.NONE),
                style(wb, "244846", "DDEDEB", false, 10, HorizontalAlignment.LEFT, BorderStyle.NONE),
                style(wb, "52706E", "EFF7F6", true, 9, HorizontalAlignment.CENTER, BorderStyle.NONE),
                style(wb, "006865", "EFF7F6", true, 14, HorizontalAlignment.CENTER, BorderStyle.NONE),
                style(wb, "FFFFFF", "087F8C", true, 10, HorizontalAlignment.CENTER, BorderStyle.THIN),
                style(wb, "FFFFFF", "087F8C", true, 10, HorizontalAlignment.LEFT, BorderStyle.THIN),
                bodyOdd, bodyEven, centerOdd, centerEven,
                style(wb, "123B3A", "FFFFFF", true, 10, HorizontalAlignment.LEFT, BorderStyle.HAIR),
                style(wb, "123B3A", "F4F8F8", true, 10, HorizontalAlignment.LEFT, BorderStyle.HAIR),
                style(wb, "006865", "E6F3F1", true, 10, HorizontalAlignment.CENTER, BorderStyle.HAIR),
                style(wb, "006865", "DCEFED", true, 10, HorizontalAlignment.CENTER, BorderStyle.HAIR),
                style(wb, "006865", "EDF7F5", true, 10, HorizontalAlignment.CENTER, BorderStyle.HAIR),
                style(wb, "006865", "E3F1EF", true, 10, HorizontalAlignment.CENTER, BorderStyle.HAIR),
                style(wb, "FFFFFF", "006865", true, 10, HorizontalAlignment.CENTER, BorderStyle.THIN),
                style(wb, "FFFFFF", "004B49", true, 11, HorizontalAlignment.CENTER, BorderStyle.THIN),
                style(wb, "123B3A", "FFFFFF", true, 10, HorizontalAlignment.LEFT, BorderStyle.HAIR),
                style(wb, "123B3A", "F4F8F8", true, 10, HorizontalAlignment.LEFT, BorderStyle.HAIR),
                decimalOdd, decimalEven,
                style(wb, "166534", "DCFCE7", true, 10, HorizontalAlignment.CENTER, BorderStyle.THIN),
                style(wb, "92400E", "FEF3C7", true, 10, HorizontalAlignment.CENTER, BorderStyle.THIN),
                style(wb, "075985", "E0F2FE", true, 10, HorizontalAlignment.CENTER, BorderStyle.THIN));
    }

    private static CellStyle style(XSSFWorkbook wb, String fontColor, String fillColor, boolean bold,
                                   int size, HorizontalAlignment alignment, BorderStyle border) {
        XSSFCellStyle style = wb.createCellStyle();
        XSSFFont font = wb.createFont();
        font.setFontName("Arial"); font.setFontHeightInPoints((short) size); font.setBold(bold);
        font.setColor(color(fontColor));
        style.setFont(font);
        style.setFillForegroundColor(color(fillColor));
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(alignment); style.setVerticalAlignment(VerticalAlignment.CENTER); style.setWrapText(true);
        style.setBorderBottom(border); style.setBorderTop(border); style.setBorderLeft(border); style.setBorderRight(border);
        short borderColor = IndexedColors.GREY_25_PERCENT.getIndex();
        style.setBottomBorderColor(borderColor); style.setTopBorderColor(borderColor);
        style.setLeftBorderColor(borderColor); style.setRightBorderColor(borderColor);
        return style;
    }

    private static CellStyle cloneWithFormat(XSSFWorkbook wb, CellStyle base, String format) {
        CellStyle style = wb.createCellStyle();
        style.cloneStyleFrom(base);
        style.setDataFormat(wb.createDataFormat().getFormat(format));
        return style;
    }

    private static XSSFColor color(String hex) {
        return new XSSFColor(java.awt.Color.decode("#" + hex), new DefaultIndexedColorMap());
    }

    private static void mergeAndSet(Sheet sheet, int firstRow, int lastRow, int firstCol, int lastCol,
                                    Object value, CellStyle style) {
        if (firstRow != lastRow || firstCol != lastCol) {
            sheet.addMergedRegion(new CellRangeAddress(firstRow, lastRow, firstCol, lastCol));
        }
        for (int r = firstRow; r <= lastRow; r++) {
            Row row = sheet.getRow(r);
            if (row == null) row = sheet.createRow(r);
            for (int c = firstCol; c <= lastCol; c++) setCell(row, c, c == firstCol && r == firstRow ? value : "", style);
        }
    }

    private static void configurePrint(Sheet sheet, String footerTitle) {
        sheet.setMargin(Sheet.LeftMargin, 0.3);
        sheet.setMargin(Sheet.RightMargin, 0.3);
        sheet.setMargin(Sheet.TopMargin, 0.45);
        sheet.setMargin(Sheet.BottomMargin, 0.45);
        sheet.getFooter().setLeft("Bệnh viện Đa khoa Minh An");
        sheet.getFooter().setCenter(footerTitle);
        sheet.getFooter().setRight("Trang &P / &N");
    }

    private static Object employeeStatusText(Object value) {
        return switch (String.valueOf(value)) {
            case "ACTIVE" -> "Chính thức";
            case "PROBATION" -> "Thử việc";
            case "INTERN" -> "Thực tập";
            case "ON_LEAVE" -> "Tạm nghỉ";
            default -> value;
        };
    }

    private static Object attendanceStatusText(Object value) {
        return switch (String.valueOf(value)) {
            case "PRESENT" -> "Đi làm đủ";
            case "PARTIAL" -> "Đi làm thiếu ca";
            case "SEMINAR" -> "Hội thảo + đi làm";
            case "ABSENT" -> "Đã check-in";
            default -> value == null ? "" : value;
        };
    }

    private static CellStyle attendanceStatusStyle(ExcelStyles styles, Object value) {
        return switch (String.valueOf(value)) {
            case "PRESENT" -> styles.statusGreen();
            case "PARTIAL", "ABSENT" -> styles.statusAmber();
            case "SEMINAR" -> styles.statusBlue();
            default -> styles.centerOdd();
        };
    }

    private static void setCell(Row row, int index, Object value, CellStyle style) {
        Cell cell = row.createCell(index);
        if (value instanceof Number n) cell.setCellValue(n.doubleValue());
        else cell.setCellValue(value == null ? "" : String.valueOf(value));
        cell.setCellStyle(style);
    }

    private static Map<String, Integer> emptyCounts(List<Category> categories) {
        Map<String, Integer> result = new LinkedHashMap<>();
        categories.forEach(c -> result.put(c.key(), 0));
        return result;
    }

    private static String fold(String value) {
        return Normalizer.normalize(value == null ? "" : value, Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "").toLowerCase(Locale.ROOT).replace('đ', 'd').trim();
    }

    private static BigDecimal nz(BigDecimal value) { return value == null ? BigDecimal.ZERO : value; }
    private static String time(java.time.LocalTime value) { return value == null ? null : value.toString().substring(0, 5); }
    private static Object firstNonBlank(Object... values) {
        return Arrays.stream(values).filter(Objects::nonNull).filter(v -> !String.valueOf(v).isBlank()).findFirst().orElse(null);
    }

    private record Category(String key, String label) {}
    private record DepartmentAccumulator(Long id, String name, Map<String, Integer> counts) {}
    private record ExcelStyles(
            CellStyle title, CellStyle subtitle, CellStyle kpiLabel, CellStyle kpiValue,
            CellStyle header, CellStyle headerLeft,
            CellStyle bodyOdd, CellStyle bodyEven, CellStyle centerOdd, CellStyle centerEven,
            CellStyle departmentOdd, CellStyle departmentEven,
            CellStyle positiveOdd, CellStyle positiveEven,
            CellStyle rowTotalOdd, CellStyle rowTotalEven,
            CellStyle total, CellStyle grandTotal,
            CellStyle nameOdd, CellStyle nameEven,
            CellStyle decimalOdd, CellStyle decimalEven,
            CellStyle statusGreen, CellStyle statusAmber, CellStyle statusBlue) {}
}
