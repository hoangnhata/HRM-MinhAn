package com.minhan.hrm.service;

import com.minhan.hrm.account.EmployeeAccountProvisioner;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.*;
import com.minhan.hrm.salary.DoctorQualifications;
import com.minhan.hrm.salary.SalaryQualifications;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import com.minhan.hrm.exception.ApiException;

import java.io.InputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class WorkforceExcelImportService {

    private final DepartmentRepository departmentRepository;
    private final PositionRepository positionRepository;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeRepository employeeRepository;
    private final SalaryInfoRepository salaryInfoRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;
    private final ContractRepository contractRepository;
    private final EmployeeSalaryProfileRepository salaryProfileRepository;
    private final EmployeeAccountProvisioner employeeAccountProvisioner;
    private final DepartmentWorkUnitService departmentWorkUnitService;
    private final EmployeeService employeeService;

    private static final DataFormatter FORMATTER = new DataFormatter(Locale.forLanguageTag("vi-VN"));

    @Transactional
    public Map<String, Object> importWorkforceExcel(MultipartFile file) {
        if (file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "File rỗng");
        }
        String fn = file.getOriginalFilename();
        if (fn == null || (!fn.toLowerCase(Locale.ROOT).endsWith(".xlsx"))) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Chỉ hỗ trợ file .xlsx (NHÂN LỰC BỆNH VIỆN MINH AN)");
        }

        final int[] created = {0};
        final int[] updated = {0};
        List<Map<String, Object>> errors = new ArrayList<>();
        List<String> sheetsProcessed = new ArrayList<>();

        try (InputStream in = file.getInputStream(); Workbook wb = new XSSFWorkbook(in)) {
            Sheet officialSalarySheet = null; // «Danh sách NV chính thức phần mềm» — có lương/thâm niên
            Sheet officialBasicSheet = null;  // «Danh sách NV chính thức» — fallback
            Sheet trialSheet = null;

            for (int si = 0; si < wb.getNumberOfSheets(); si++) {
                Sheet sheet = wb.getSheetAt(si);
                if (sheet == null || sheet.getPhysicalNumberOfRows() < 2) {
                    continue;
                }
                String name = stripAccents(sheet.getSheetName());
                if (trialSheet == null && (name.contains("thu viec") || name.contains("thuc tap"))) {
                    trialSheet = sheet;
                } else if (name.contains("chinh thuc") && (name.contains("phan") || name.contains("mem") || name.contains("am"))) {
                    officialSalarySheet = sheet;
                } else if (officialBasicSheet == null && name.contains("chinh thuc")) {
                    officialBasicSheet = sheet;
                }
            }

            // Ưu tiên sheet phần mềm (có cột lương/thâm niên); nếu không có thì dùng sheet chính thức thường.
            Sheet officialSheet = officialSalarySheet != null ? officialSalarySheet : officialBasicSheet;
            if (officialSheet != null) {
                String label = officialSheet.getSheetName();
                importOfficialSheet(officialSheet, label, EmploymentType.FULL_TIME, errors,
                        () -> created[0]++, () -> updated[0]++);
                sheetsProcessed.add(label + " (toàn thời gian)");
            }
            if (trialSheet != null) {
                String label = trialSheet.getSheetName();
                importTrialSheet(trialSheet, label, errors, () -> created[0]++, () -> updated[0]++);
                sheetsProcessed.add(label + " (thử việc/thực tập)");
            }

            if (officialSheet == null && trialSheet == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Không tìm thấy sheet \"Danh sách NV chính thức\" hoặc \"Thử việcThực tập\".");
            }
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.error("Import Excel lỗi", e);
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đọc được file Excel: " + e.getMessage());
        }

        return Map.of(
                "created", created[0],
                "updated", updated[0],
                "errors", errors,
                "sheetsProcessed", sheetsProcessed);
    }

    private void importOfficialSheet(
            Sheet sheet,
            String sheetLabel,
            EmploymentType defaultEmploymentType,
            List<Map<String, Object>> errors,
            Runnable onCreated,
            Runnable onUpdated) {
        int headerRowIdx = findHeaderRow(sheet, "mã nhân viên", "họ và tên");
        if (headerRowIdx < 0) {
            errors.add(Map.of("row", 0, "message", "Sheet \"" + sheetLabel + "\": không tìm thấy tiêu đề cột chính thức"));
            return;
        }
        Row headerRow = sheet.getRow(headerRowIdx);
        Map<String, Integer> col = buildHeaderMap(headerRow);
        int last = sheet.getLastRowNum();
        for (int r = headerRowIdx + 1; r <= last; r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                continue;
            }
            try {
                String code = cellString(sheet, r, col, "mã nhân viên");
                if (code == null || code.isBlank()) {
                    continue;
                }
                code = normalizeEmployeeCode(code.trim());
                String fullName = cellString(sheet, r, col, "họ và tên");
                if (fullName == null || fullName.isBlank()) {
                    errors.add(rowError(sheetLabel, r, "Thiếu họ tên"));
                    continue;
                }
                if (isSparseOfficialRow(sheet, r, col)) {
                    continue;
                }
                EmploymentType employmentType = parseEmploymentType(
                        cellString(sheet, r, col, "loại hđ", "loai hd"), defaultEmploymentType);
                boolean wasUpdate = upsertOfficialRow(sheet, r, col, code, fullName.trim(), employmentType);
                if (wasUpdate) {
                    onUpdated.run();
                } else {
                    onCreated.run();
                }
            } catch (Exception ex) {
                log.warn("Import {} row {}: {}", sheetLabel, r + 1, ex.getMessage());
                errors.add(rowError(sheetLabel, r, ex.getMessage() != null ? ex.getMessage() : "Lỗi không xác định"));
            }
        }
    }

    private void importPartTimeSheet(
            Sheet sheet,
            String sheetLabel,
            List<Map<String, Object>> errors,
            Runnable onCreated,
            Runnable onUpdated) {
        int headerRowIdx = findHeaderRow(sheet, "họ và tên", "đơn vị công tác");
        if (headerRowIdx < 0) {
            headerRowIdx = findHeaderRow(sheet, "họ và tên", "vị trí làm việc");
        }
        if (headerRowIdx < 0) {
            errors.add(Map.of("row", 0, "message", "Sheet \"" + sheetLabel + "\": không tìm thấy tiêu đề BTG"));
            return;
        }
        Row headerRow = sheet.getRow(headerRowIdx);
        Map<String, Integer> col = buildHeaderMap(headerRow);
        int last = sheet.getLastRowNum();
        int emptyStreak = 0;
        for (int r = headerRowIdx + 1; r <= last; r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                emptyStreak++;
                if (emptyStreak >= 8) {
                    break;
                }
                continue;
            }
            try {
                String fullName = cellString(sheet, r, col, "họ và tên", "họ tên");
                if (fullName == null || fullName.isBlank()) {
                    emptyStreak++;
                    if (emptyStreak >= 8) {
                        break;
                    }
                    continue;
                }
                emptyStreak = 0;
                fullName = fullName.trim();
                if (fullName.equalsIgnoreCase("họ và tên") || fullName.equalsIgnoreCase("stt") || isNumericOnly(fullName)) {
                    continue;
                }
                String cccd = firstNonNullStr(
                        cellString(sheet, r, col, "mã cccd", "cccd"),
                        cellString(sheet, r, col, "mã cmnd"));
                String code = firstNonNullStr(
                        cellString(sheet, r, col, "mã nhân viên"),
                        cccd != null ? normalizeEmployeeCode(cccd) : null);
                if (code == null || code.isBlank()) {
                    code = generatePartTimeCode(fullName, cellDate(sheet, r, col, "ngày sinh"));
                } else {
                    code = normalizeEmployeeCode(code);
                }
                boolean wasUpdate = upsertOfficialRow(sheet, r, col, code, fullName, EmploymentType.PART_TIME);
                if (wasUpdate) {
                    onUpdated.run();
                } else {
                    onCreated.run();
                }
            } catch (Exception ex) {
                log.warn("Import BTG {} row {}: {}", sheetLabel, r + 1, ex.getMessage());
                errors.add(rowError(sheetLabel, r, ex.getMessage() != null ? ex.getMessage() : "Lỗi không xác định"));
            }
        }
    }

    private void importTrialSheet(
            Sheet sheet,
            String sheetLabel,
            List<Map<String, Object>> errors,
            Runnable onCreated,
            Runnable onUpdated) {
        int headerRowIdx = findHeaderRow(sheet, "họ tên", "bộ phận");
        if (headerRowIdx < 0) {
            headerRowIdx = findHeaderRow(sheet, "họ tên", "từ ngày");
        }
        if (headerRowIdx < 0) {
            headerRowIdx = findHeaderRow(sheet, "họ tên", "đơn vị công tác");
        }
        if (headerRowIdx < 0) {
            errors.add(Map.of("row", 0, "message", "Sheet \"" + sheetLabel + "\": không tìm thấy tiêu đề sheet thử việc"));
            return;
        }
        Row headerRow = sheet.getRow(headerRowIdx);
        Map<String, Integer> col = buildHeaderMap(headerRow);
        int last = sheet.getLastRowNum();
        int emptyStreak = 0;
        for (int r = headerRowIdx + 1; r <= last; r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                emptyStreak++;
                if (emptyStreak >= 8) {
                    break;
                }
                continue;
            }
            try {
                String fullName = cellString(sheet, r, col, "họ tên", "họ và tên");
                if (fullName == null || fullName.isBlank()) {
                    emptyStreak++;
                    if (emptyStreak >= 8) {
                        break;
                    }
                    continue;
                }
                emptyStreak = 0;
                fullName = fullName.trim();
                if (fullName.equalsIgnoreCase("họ tên") || fullName.equalsIgnoreCase("stt") || isNumericOnly(fullName)) {
                    continue;
                }
                boolean wasUpdate = upsertTrialRow(sheet, r, col, fullName);
                if (wasUpdate) {
                    onUpdated.run();
                } else {
                    onCreated.run();
                }
            } catch (Exception ex) {
                log.warn("Import trial {} row {}: {}", sheetLabel, r + 1, ex.getMessage());
                errors.add(rowError(sheetLabel, r, ex.getMessage() != null ? ex.getMessage() : "Lỗi không xác định"));
            }
        }
    }

    /** Bỏ qua dòng chỉ có mã + tên (bản ghi trùng/thiếu trong Excel). */
    private boolean isSparseOfficialRow(Sheet sheet, int rowIndex, Map<String, Integer> col) {
        boolean hasDept = cellString(sheet, rowIndex, col, "đơn vị công tác") != null;
        boolean hasPhone = cellString(sheet, rowIndex, col, "đt di động", "sdt") != null;
        boolean hasDob = cellDate(sheet, rowIndex, col, "ngày sinh") != null;
        boolean hasEmail = cellString(sheet, rowIndex, col, "email") != null;
        boolean hasGender = cellString(sheet, rowIndex, col, "giới tính") != null;
        boolean hasPosition = cellString(sheet, rowIndex, col,
                "vị trí làm việc", "vị trí", "chức danh chuyên môn") != null;
        int filled = (hasDept ? 1 : 0) + (hasPhone ? 1 : 0) + (hasDob ? 1 : 0)
                + (hasEmail ? 1 : 0) + (hasGender ? 1 : 0) + (hasPosition ? 1 : 0);
        return filled < 2;
    }

    private static Map<String, Object> rowError(String sheet, int rowIndex, String message) {
        return Map.of("row", rowIndex + 1, "sheet", sheet, "message", message);
    }

    /** Danh mục phòng ban chuẩn theo sheet «DS NV chính thức phần mềm». */
    private static final List<String> CANONICAL_DEPARTMENTS = List.of(
            "BAN GIÁM ĐỐC",
            "KHOA CHẨN ĐOÁN HÌNH ẢNH",
            "KHOA DƯỢC",
            "KHOA GÂY MÊ HỒI SỨC",
            "KHOA HỒI SỨC CẤP CỨU",
            "KHOA KHÁM BỆNH",
            "KHOA LIÊN CHUYÊN KHOA",
            "KHOA NGOẠI",
            "KHOA NỘI - NHI",
            "KHOA SẢN",
            "KHOA XÉT NGHIỆM",
            "KHOA Y HỌC CỔ TRUYỀN",
            "PHÒNG HÀNH CHÍNH - NHÂN SỰ",
            "PHÒNG KINH DOANH & PHÁT TRIỂN",
            "PHÒNG KẾ HOẠCH TỔNG HỢP",
            "PHÒNG TÀI CHÍNH - KẾ TOÁN"
    );

    /**
     * Chuẩn hóa tên phòng ban (Đơn vị công tác) về đúng Excel phần mềm.
     * Sheet thử việc hay viết tắt: Khoa HSCC, Khoa Nội - Nhi, Khoa YHCT -PHCN…
     */
    private static String canonicalizeDepartmentName(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String trimmed = raw.trim().replaceAll("\\s+", " ");
        String key = orgKey(trimmed);

        if (key.isEmpty()) {
            return trimmed;
        }
        // Alias phổ biến trên sheet thử việc / sheet chính thức cũ
        if (key.equals("hscc") || key.equals("hoisuccapcuu") || key.equals("khoahscc")) {
            return "KHOA HỒI SỨC CẤP CỨU";
        }
        if (key.equals("yhct") || key.equals("yhctphcn") || key.equals("khoayhctphcn")
                || key.equals("yhoccotruyen") || key.equals("khoayhoccotruyen")) {
            return "KHOA Y HỌC CỔ TRUYỀN";
        }
        if (key.equals("noinhi") || key.equals("khoanoinhi")) {
            return "KHOA NỘI - NHI";
        }

        for (String canonical : CANONICAL_DEPARTMENTS) {
            if (orgKey(canonical).equals(key)) {
                return canonical;
            }
        }
        return trimmed;
    }

    /**
     * Chuẩn hóa bộ phận theo cặp Excel: Phòng ban → Bộ phận.
     * Giữ nguyên tên bộ phận con (RHM, THU NGÂN, NHI…); chỉ sửa alias của chính khoa/phòng.
     */
    private static String canonicalizeWorkUnit(String departmentCanonical, String unitRaw) {
        if (departmentCanonical == null || departmentCanonical.isBlank()) {
            return trimStatic(unitRaw);
        }
        String unit = trimStatic(unitRaw);
        if (unit == null) {
            return primaryWorkUnitFor(departmentCanonical);
        }
        String uk = orgKey(unit);
        String dk = orgKey(departmentCanonical);
        String primary = primaryWorkUnitFor(departmentCanonical);

        // Trùng khóa với tên phòng ban → bộ phận chuẩn của khoa
        if (uk.equals(dk)) {
            return primary;
        }

        // Alias của phòng ban (Khoa HSCC, Khoa Nội - Nhi…) → bộ phận chuẩn
        String unitAsDept = canonicalizeDepartmentName(unit);
        if (unitAsDept != null && unitAsDept.equals(departmentCanonical) && !uk.equals(orgKey(primary))) {
            return primary;
        }

        // Alias bộ phận con đã biết
        if ("KHOA LIÊN CHUYÊN KHOA".equals(departmentCanonical)) {
            if (uk.equals("ranghammat") || uk.equals("rhm")) {
                return "RHM";
            }
            if (uk.equals("tmh") || uk.equals("taimuihong")) {
                return "TMH";
            }
            if (uk.equals("mat")) {
                return "MẮT";
            }
        }
        if ("PHÒNG TÀI CHÍNH - KẾ TOÁN".equals(departmentCanonical)) {
            if (uk.equals("thungan") || uk.equals("bophanthungan")) {
                return "THU NGÂN";
            }
            if (uk.equals("ketoan")) {
                return "KẾ TOÁN";
            }
        }
        if ("PHÒNG KINH DOANH & PHÁT TRIỂN".equals(departmentCanonical)) {
            if (uk.equals("cskh") || uk.equals("chamsockhachhang")) {
                return "CHĂM SÓC KHÁCH HÀNG";
            }
            if (uk.contains("marketing") || uk.equals("kinhdoanhmarketing")) {
                return "KINH DOANH - MARKETING";
            }
        }
        if ("PHÒNG HÀNH CHÍNH - NHÂN SỰ".equals(departmentCanonical)) {
            if (uk.equals("cntt") || uk.equals("congnghethongtin") || uk.equals("it")) {
                return "CÔNG NGHỆ THÔNG TIN";
            }
            if (uk.equals("holy")) {
                return "HỘ LÝ";
            }
        }

        // Giữ nguyên đúng chữ Excel (đã trim)
        return unit;
    }

    /** Bộ phận mặc định khi Excel để trống hoặc ghi trùng tên khoa. */
    private static String primaryWorkUnitFor(String departmentCanonical) {
        if ("KHOA HỒI SỨC CẤP CỨU".equals(departmentCanonical)) {
            return "HỒI SỨC CẤP CỨU";
        }
        if ("PHÒNG HÀNH CHÍNH - NHÂN SỰ".equals(departmentCanonical)) {
            return "HÀNH CHÍNH - NHÂN SỰ";
        }
        return departmentCanonical;
    }

    /** Khóa so khớp: bỏ dấu, bỏ tiền tố khoa/phòng, bỏ ký tự đặc biệt. */
    private static String orgKey(String s) {
        if (s == null) {
            return "";
        }
        String t = stripAccents(s)
                .replaceAll("^(khoa|phong)\\s+", "")
                .replaceAll("[^a-z0-9]", "");
        return t;
    }

    private static String trimStatic(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        return s.trim().replaceAll("\\s+", " ");
    }

    /** Đọc đúng cột Đơn vị công tác / Bộ phận (không fuzzy lẫn cột khác). */
    private String[] readOrgColumns(Sheet sheet, int rowIndex, Map<String, Integer> col) {
        int deptIdx = resolveColExact(col, "đơn vị công tác", "don vi cong tac");
        int unitIdx = resolveColExact(col, "bộ phận", "bo phan");
        String deptRaw = deptIdx >= 0 ? cellStringAt(sheet, rowIndex, deptIdx) : null;
        String unitRaw = unitIdx >= 0 ? cellStringAt(sheet, rowIndex, unitIdx) : null;
        // Fallback cũ nếu header lệch
        if (deptRaw == null) {
            deptRaw = cellString(sheet, rowIndex, col, "đơn vị công tác", "khoa/phòng", "khoa phòng");
        }
        if (unitRaw == null) {
            unitRaw = cellString(sheet, rowIndex, col, "bộ phận", "bo phan");
        }
        String dept = canonicalizeDepartmentName(deptRaw);
        String unit = canonicalizeWorkUnit(dept, unitRaw);
        return new String[]{dept, unit};
    }

    private int resolveColExact(Map<String, Integer> col, String... aliases) {
        for (String a : aliases) {
            String k = normalizeHeader(a);
            if (col.containsKey(k)) {
                return col.get(k);
            }
        }
        return -1;
    }

    private String cellStringAt(Sheet sheet, int rowIndex, int columnIndex) {
        Cell cell = getEffectiveCell(sheet, rowIndex, columnIndex);
        if (cell == null) {
            return null;
        }
        String v = formatCellCached(cell);
        return v == null || v.isEmpty() ? null : v;
    }

    /** Bỏ dấu tiếng Việt + hạ chữ thường để so khớp tên sheet không phụ thuộc dấu. */
    private static String stripAccents(String s) {
        if (s == null) {
            return "";
        }
        String normalized = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD)
                .replaceAll("\\p{InCombiningDiacriticalMarks}+", "")
                .replace('\u0111', 'd')
                .replace('\u0110', 'D');
        return normalized.toLowerCase(Locale.ROOT).replaceAll("\\s+", " ").trim();
    }

    private static int findHeaderRow(Sheet sheet, String... mustHaveAliases) {
        int max = Math.min(12, sheet.getLastRowNum());
        for (int r = 0; r <= max; r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                continue;
            }
            Map<String, Integer> col = buildHeaderMapStatic(row);
            boolean ok = true;
            for (String alias : mustHaveAliases) {
                if (resolveColStatic(col, alias) < 0) {
                    ok = false;
                    break;
                }
            }
            if (ok) {
                return r;
            }
        }
        return -1;
    }

    private static Map<String, Integer> buildHeaderMapStatic(Row headerRow) {
        Map<String, Integer> map = new HashMap<>();
        short last = headerRow.getLastCellNum();
        for (int c = 0; c < last; c++) {
            Cell cell = headerRow.getCell(c);
            String raw = FORMATTER.formatCellValue(cell).trim();
            if (raw.isEmpty()) {
                continue;
            }
            map.put(normalizeHeader(raw), c);
        }
        return map;
    }

    private static int resolveColStatic(Map<String, Integer> col, String... aliases) {
        for (String a : aliases) {
            String k = normalizeHeader(a);
            if (col.containsKey(k)) {
                return col.get(k);
            }
        }
        for (String a : aliases) {
            String sub = normalizeHeader(a);
            for (Map.Entry<String, Integer> e : col.entrySet()) {
                if (e.getKey().contains(sub) || sub.contains(e.getKey())) {
                    return e.getValue();
                }
            }
        }
        return -1;
    }

    private boolean upsertOfficialRow(
            Sheet sheet, int rowIndex, Map<String, Integer> col,
            String employeeCode, String fullName, EmploymentType employmentType) {
        LocalDate probation = cellDate(sheet, rowIndex, col, "ngày thử việc");
        LocalDate official = cellDate(sheet, rowIndex, col, "ngày chính thức");
        return upsertRow(sheet, rowIndex, col, employeeCode, fullName,
                EmployeeStatus.ACTIVE, employmentType, probation, official);
    }

    private boolean upsertTrialRow(Sheet sheet, int rowIndex, Map<String, Integer> col, String fullName) {
        LocalDate dob = cellDate(sheet, rowIndex, col, "ngày sinh");
        LocalDate fromDate = cellDate(sheet, rowIndex, col, "từ ngày", "tu ngay");
        String positionTitle = cellString(sheet, rowIndex, col, "vị trí", "vi tri");
        String degree = firstNonNullStr(
                cellString(sheet, rowIndex, col, "bằng cấp", "bang cap"),
                cellString(sheet, rowIndex, col, "trình độ", "trinh do"));
        String note = cellString(sheet, rowIndex, col, "ghi chú", "ghi chu");
        String salaryNote = cellString(sheet, rowIndex, col, "mức lương", "muc luong");
        String phone = cellString(sheet, rowIndex, col, "sdt", "sđt", "đt di động", "so dien thoai");
        String cccd = firstNonNullStr(
                cellString(sheet, rowIndex, col, "số cccd", "so cccd"),
                cellString(sheet, rowIndex, col, "mã cccd", "cccd"));
        if (cccd != null) {
            cccd = normalizeEmployeeCode(cccd);
        }
        String workUnitName = null; // set after reading org columns
        boolean isProbationMark = isMarkedFlag(cellString(sheet, rowIndex, col, "thử việc", "thu viec"));
        boolean isPracticeMark = isMarkedFlag(cellString(sheet, rowIndex, col, "thực hành", "thuc hanh", "thực tập", "thuc tap"));
        String trialType = resolveTrialType(isProbationMark, isPracticeMark, positionTitle, note);
        EmployeeStatus status = statusFromTrialType(trialType);

        // Phòng ban = Đơn vị công tác; Bộ phận = cột Bộ phận — chuẩn hóa giống sheet chính thức Excel
        String[] org = readOrgColumns(sheet, rowIndex, col);
        String deptName = org[0];
        workUnitName = org[1];
        Department dept = findOrCreateDepartment(deptName);
        Position pos = findOrCreatePosition(positionTitle);
        if (dept != null && workUnitName != null && !workUnitName.isBlank()) {
            departmentWorkUnitService.findOrCreate(dept, workUnitName);
        }

        Optional<Employee> trialExisting = findTrialOnlyEmployee(fullName, dob, fromDate);
        Optional<Employee> officialExisting = findOfficialByNameAndDob(fullName, dob);

        if (officialExisting.isPresent()) {
            Employee emp = officialExisting.get();
            applyTrialStatus(emp, status, fromDate, dept, pos);
            mergeStringField(emp::getPhone, emp::setPhone, phone);
            mergeStringField(emp::getIdCardNumber, emp::setIdCardNumber, cccd);
            saveTrialWorkforceDetails(sheet, rowIndex, col, emp, fromDate, note, salaryNote, degree, workUnitName, trialType);
            employeeRepository.save(emp);
            syncImportedPhoneLogin(emp);
            return true;
        }

        if (trialExisting.isPresent()) {
            Employee emp = trialExisting.get();
            UserAccount user = emp.getUser();
            emp.setFullName(fullName);
            if (dob != null) {
                emp.setDateOfBirth(dob);
            }
            mergeStringField(emp::getPhone, emp::setPhone, phone);
            mergeStringField(emp::getIdCardNumber, emp::setIdCardNumber, cccd);
            emp.setDepartment(dept);
            emp.setPosition(pos);
            if (fromDate != null) {
                emp.setHireDate(fromDate);
            }
            if (emp.getStatus() != EmployeeStatus.TERMINATED) {
                emp.setStatus(status);
            }
            employeeAccountProvisioner.applyImportRole(user, dept, pos);
            employeeRepository.save(emp);
            userAccountRepository.save(user);
            syncImportedPhoneLogin(emp);
            saveTrialWorkforceDetails(sheet, rowIndex, col, emp, fromDate, note, salaryNote, degree, workUnitName, trialType);
            return true;
        }

        String employeeCode = generateTrialCode(fullName, dob, fromDate);
        LocalDate hire = fromDate != null ? fromDate : LocalDate.now();
        String email = ensureUniqueEmail("tv_" + sanitizeUsername(employeeCode) + "@import.minhan.vn", employeeCode);

        UserRole role = employeeAccountProvisioner.resolveImportRole(dept, pos);
        UserAccount user = employeeAccountProvisioner.buildNewEmployeeUser(phone, employeeCode, email, role);
        user = userAccountRepository.save(user);

        Employee emp = Employee.builder()
                .user(user)
                .employeeCode(employeeCode)
                .fullName(fullName)
                .phone(trimToNull(phone))
                .idCardNumber(trimToNull(cccd))
                .dateOfBirth(dob)
                .department(dept)
                .position(pos)
                .hireDate(hire)
                .status(status)
                .build();
        emp = employeeRepository.save(emp);

        salaryInfoRepository.save(SalaryInfo.builder()
                .employee(emp)
                .baseSalary(BigDecimal.ZERO)
                .allowance(BigDecimal.ZERO)
                .nextReviewDate(hire.plusYears(1))
                .build());

        saveTrialWorkforceDetails(sheet, rowIndex, col, emp, fromDate, note, salaryNote, degree, workUnitName, trialType);
        return false;
    }

    private void applyTrialStatus(
            Employee emp, EmployeeStatus status, LocalDate fromDate, Department dept, Position pos) {
        if (emp.getStatus() != EmployeeStatus.TERMINATED) {
            emp.setStatus(status);
        }
        if (fromDate != null) {
            emp.setHireDate(fromDate);
        }
        if (dept != null && dept.getCode() != null && !"CHUNG".equals(dept.getCode())) {
            emp.setDepartment(dept);
        }
        if (pos != null && pos.getCode() != null && !"NV".equals(pos.getCode())) {
            emp.setPosition(pos);
        }
    }

    private void saveTrialWorkforceDetails(
            Sheet sheet,
            int rowIndex,
            Map<String, Integer> col,
            Employee emp,
            LocalDate fromDate,
            String note,
            String salaryNote,
            String degree,
            String workUnitName,
            String trialType) {
        EmployeeWorkforceDetails d = workforceDetailsRepository.findByEmployee(emp).orElse(
                EmployeeWorkforceDetails.builder().employee(emp).build());
        String degreeFromSheet = firstNonNullStr(
                cellString(sheet, rowIndex, col, "bằng cấp", "bang cap"),
                cellString(sheet, rowIndex, col, "trình độ", "trinh do"),
                degree);
        if (degreeFromSheet != null) {
            d.setDegree(degreeFromSheet);
        }
        d.setProbationStartDate(fromDate);
        String unit = firstNonNullStr(workUnitName, readOrgColumns(sheet, rowIndex, col)[1]);
        if (unit != null) {
            d.setWorkUnitDetail(unit);
        }
        String attendance = trimToNull(cellString(sheet, rowIndex, col, "mã chấm công", "ma cham cong"));
        if (attendance != null) {
            d.setAttendanceCode(attendance);
        }
        if (trialType != null) {
            d.setTrialType(trialType);
        }
        d.setWorkforceNotes(buildTrialNotes(note, salaryNote));
        workforceDetailsRepository.save(d);
    }

    private static String buildTrialNotes(String note, String salaryNote) {
        StringBuilder sb = new StringBuilder();
        if (note != null && !note.isBlank()) {
            sb.append(note.trim());
        }
        if (salaryNote != null && !salaryNote.isBlank()) {
            if (sb.length() > 0) {
                sb.append(" | ");
            }
            sb.append("Mức lương: ").append(salaryNote.trim());
        }
        return sb.length() > 0 ? sb.toString() : null;
    }

    /** Chỉ tìm hồ sơ thử việc (TV- hoặc PROBATION/INTERN) — không đụng NV chính thức. */
    private Optional<Employee> findTrialOnlyEmployee(String fullName, LocalDate dob, LocalDate fromDate) {
        List<Employee> byName = employeeRepository.findByFullNameIgnoreCaseTrim(fullName);
        if (byName.isEmpty()) {
            return Optional.empty();
        }
        List<Employee> trials = byName.stream().filter(this::isTrialRecord).toList();
        if (trials.isEmpty()) {
            return Optional.empty();
        }
        if (dob != null) {
            Optional<Employee> byDob = trials.stream().filter(e -> dob.equals(e.getDateOfBirth())).findFirst();
            if (byDob.isPresent()) {
                return byDob;
            }
        }
        if (fromDate != null) {
            Optional<Employee> byDate = trials.stream().filter(e -> fromDate.equals(e.getHireDate())).findFirst();
            if (byDate.isPresent()) {
                return byDate;
            }
        }
        return trials.stream().findFirst();
    }

    /** NV chính thức cùng tên + ngày sinh (có trong sheet thử việc nhưng đã có hồ sơ đầy đủ). */
    private Optional<Employee> findOfficialByNameAndDob(String fullName, LocalDate dob) {
        if (dob == null) {
            return Optional.empty();
        }
        return employeeRepository.findByFullNameIgnoreCaseTrim(fullName).stream()
                .filter(e -> e.getStatus() == EmployeeStatus.ACTIVE || e.getStatus() == EmployeeStatus.ON_LEAVE)
                .filter(e -> dob.equals(e.getDateOfBirth()))
                .findFirst();
    }

    private boolean isTrialRecord(Employee e) {
        if (e.getStatus() == EmployeeStatus.PROBATION || e.getStatus() == EmployeeStatus.INTERN) {
            return true;
        }
        String code = e.getEmployeeCode();
        return code != null && code.toUpperCase(Locale.ROOT).startsWith("TV-");
    }

    private static boolean isNumericOnly(String s) {
        if (s == null || s.isBlank()) {
            return false;
        }
        return s.replace(".", "").replace(",", "").matches("\\d+");
    }

    private static String normalizeEmployeeCode(String raw) {
        if (raw == null) {
            return null;
        }
        String s = raw.trim().replaceAll("\\s+", "");
        if (s.matches("\\d+\\.0+")) {
            s = s.substring(0, s.indexOf('.'));
        }
        // POI đôi khi trả CCCD dạng scientific (4.0187E10)
        if (s.matches("(?i)\\d+(\\.\\d+)?e\\+?\\d+")) {
            try {
                s = new BigDecimal(s).toPlainString();
                if (s.contains(".")) {
                    s = s.substring(0, s.indexOf('.'));
                }
            } catch (NumberFormatException ignored) {
            }
        }
        // CCCD 12 số — Excel/POI hay làm mất 0 đầu (11 hoặc 10 chữ số)
        if (s.matches("\\d{10,11}")) {
            s = String.format("%012d", Long.parseLong(s));
        }
        return s;
    }

    /** Bỏ 0 đầu để khớp bản ghi import cũ bị thiếu số 0. */
    private static String stripLeadingZeros(String digits) {
        if (digits == null || !digits.matches("\\d+")) {
            return null;
        }
        String s = digits.replaceFirst("^0+", "");
        return s.isEmpty() ? "0" : s;
    }

    private static EmployeeStatus inferTrialStatus(String position, String note) {
        String combined = ((position != null ? position : "") + " " + (note != null ? note : "")).toLowerCase(Locale.ROOT);
        if (combined.contains("thực tập") || combined.contains("thuc tap")
                || combined.contains("thực hành") || combined.contains("thuc hanh")
                || combined.contains("intern")) {
            return EmployeeStatus.INTERN;
        }
        return EmployeeStatus.PROBATION;
    }

    /** Cột Excel đánh dấu X / ✓ / 1 */
    private static boolean isMarkedFlag(String raw) {
        if (raw == null || raw.isBlank()) {
            return false;
        }
        String t = raw.trim().toLowerCase(Locale.ROOT);
        return t.equals("x") || t.equals("✓") || t.equals("✔") || t.equals("1")
                || t.equals("true") || t.equals("yes") || t.equals("có") || t.equals("co");
    }

    private static String resolveTrialType(
            boolean probationMark, boolean practiceMark, String position, String note) {
        if (probationMark && practiceMark) {
            return "BOTH";
        }
        if (practiceMark) {
            return "THUC_HANH";
        }
        if (probationMark) {
            return "THU_VIEC";
        }
        EmployeeStatus fallback = inferTrialStatus(position, note);
        return fallback == EmployeeStatus.INTERN ? "THUC_HANH" : "THU_VIEC";
    }

    private static EmployeeStatus statusFromTrialType(String trialType) {
        if ("THUC_HANH".equals(trialType)) {
            return EmployeeStatus.INTERN;
        }
        return EmployeeStatus.PROBATION;
    }

    private String generateTrialCode(String fullName, LocalDate dob, LocalDate fromDate) {
        String suffix;
        if (dob != null) {
            suffix = dob.format(DateTimeFormatter.ofPattern("ddMMyyyy"));
        } else if (fromDate != null) {
            suffix = fromDate.format(DateTimeFormatter.ofPattern("ddMMyyyy"));
        } else {
            suffix = Integer.toHexString(Math.abs(fullName.hashCode())).toUpperCase(Locale.ROOT);
            if (suffix.length() > 8) {
                suffix = suffix.substring(0, 8);
            }
        }
        String base = "TV-" + suffix;
        String code = base;
        int i = 0;
        while (employeeRepository.existsByEmployeeCode(code)) {
            code = base + "-" + (++i);
        }
        return code;
    }

    private boolean upsertRow(
            Sheet sheet,
            int rowIndex,
            Map<String, Integer> col,
            String employeeCode,
            String fullName,
            EmployeeStatus targetStatus,
            EmploymentType employmentType,
            LocalDate probationOverride,
            LocalDate officialOverride) {
        Department dept;
        {
            String[] org = readOrgColumns(sheet, rowIndex, col);
            dept = findOrCreateDepartment(org[0]);
            if (dept != null && org[1] != null && !org[1].isBlank()) {
                departmentWorkUnitService.findOrCreate(dept, org[1]);
            }
        }
        Position pos = findOrCreatePosition(cellString(sheet, rowIndex, col,
                "vị trí làm việc", "vị trí", "chức danh chuyên môn"));

        LocalDate dob = cellDate(sheet, rowIndex, col, "ngày sinh");
        String phone = cellString(sheet, rowIndex, col, "đt di động", "dt di dong", "sdt", "sđt", "so dien thoai");
        String address = cellString(sheet, rowIndex, col, "địa chỉ");
        String cccd = firstNonNullStr(
                cellString(sheet, rowIndex, col, "mã cccd", "cccd"),
                cellString(sheet, rowIndex, col, "mã cmnd"));
        if (cccd != null) {
            cccd = normalizeEmployeeCode(cccd);
        }
        LocalDate cccdIssue = cellDate(sheet, rowIndex, col, "ngày cấp cccd", "ngày cấp");
        String emailRaw = cellString(sheet, rowIndex, col, "email");
        String email = (emailRaw == null || emailRaw.isBlank())
                ? ("nv_" + sanitizeUsername(employeeCode) + "@import.minhan.vn")
                : emailRaw.trim();
        email = ensureUniqueEmail(email, employeeCode);

        LocalDate hire = firstNonNull(
                officialOverride,
                cellDate(sheet, rowIndex, col, "ngày chính thức"),
                cellDate(sheet, rowIndex, col, "thời gian bắt đầu tính thang bảng lương"),
                cellDate(sheet, rowIndex, col, "ngày thử việc"),
                probationOverride,
                LocalDate.now());

        Optional<Employee> existing = employeeRepository.findByEmployeeCode(employeeCode);
        if (existing.isEmpty()) {
            // Bản ghi cũ có thể thiếu 0 đầu (Excel numeric) — khớp mã đã bỏ 0 đầu
            String unpaddedCode = stripLeadingZeros(employeeCode);
            if (unpaddedCode != null && !unpaddedCode.equals(employeeCode)) {
                existing = employeeRepository.findByEmployeeCode(unpaddedCode);
            }
        }
        if (existing.isEmpty() && cccd != null) {
            String normalizedCccd = normalizeEmployeeCode(cccd);
            existing = employeeRepository.findByIdCardNumberNormalized(normalizedCccd);
            if (existing.isEmpty()) {
                String unpaddedCccd = stripLeadingZeros(normalizedCccd);
                if (unpaddedCccd != null && !unpaddedCccd.equals(normalizedCccd)) {
                    existing = employeeRepository.findByIdCardNumberNormalized(unpaddedCccd);
                }
            }
        }
        Employee emp;
        UserAccount user;

        if (existing.isPresent()) {
            emp = existing.get();
            user = emp.getUser();
            if (!email.equalsIgnoreCase(user.getEmail()) && userAccountRepository.existsByEmail(email)) {
                email = ensureUniqueEmail(email, employeeCode);
            }
            user.setEmail(email);
            emp.setFullName(fullName);
            // Sửa mã NV / CCCD nếu lần import trước bị mất số 0 đầu
            if (employeeCode != null && !employeeCode.equals(emp.getEmployeeCode())
                    && !employeeRepository.existsByEmployeeCode(employeeCode)) {
                emp.setEmployeeCode(employeeCode);
            }
            mergeStringField(emp::getPhone, emp::setPhone, phone);
            mergeStringField(emp::getIdCardNumber, emp::setIdCardNumber, cccd);
            if (dob != null) {
                emp.setDateOfBirth(dob);
            }
            mergeStringField(emp::getAddress, emp::setAddress, address);
            mergeStringField(emp::getGender, emp::setGender, cellString(sheet, rowIndex, col, "giới tính"));
            emp.setDepartment(dept);
            emp.setPosition(pos);
            if (hire != null) {
                emp.setHireDate(hire);
            }
            if (employmentType != null) {
                emp.setEmploymentType(employmentType);
            }
            if (emp.getStatus() != EmployeeStatus.TERMINATED) {
                emp.setStatus(targetStatus);
            }
            employeeAccountProvisioner.applyImportRole(user, dept, pos);
            employeeRepository.save(emp);
            userAccountRepository.save(user);
            syncImportedPhoneLogin(emp);
            saveWorkforceDetails(sheet, rowIndex, col, emp);
            saveContractIfAny(sheet, rowIndex, col, emp);
            saveSalaryProfileIfAny(sheet, rowIndex, col, emp);
            return true;
        }

        UserRole role = employeeAccountProvisioner.resolveImportRole(dept, pos);
        user = employeeAccountProvisioner.buildNewEmployeeUser(phone, employeeCode, email, role);
        user = userAccountRepository.save(user);

        emp = Employee.builder()
                .user(user)
                .employeeCode(employeeCode)
                .fullName(fullName)
                .phone(trimToNull(phone))
                .idCardNumber(trimToNull(cccd))
                .dateOfBirth(dob)
                .address(trimToNull(address))
                .gender(trimToNull(cellString(sheet, rowIndex, col, "giới tính")))
                .department(dept)
                .position(pos)
                .hireDate(hire)
                .status(targetStatus)
                .employmentType(employmentType != null ? employmentType : EmploymentType.FULL_TIME)
                .build();
        emp = employeeRepository.save(emp);

        salaryInfoRepository.save(SalaryInfo.builder()
                .employee(emp)
                .baseSalary(BigDecimal.ZERO)
                .allowance(BigDecimal.ZERO)
                .nextReviewDate(hire.plusYears(1))
                .build());

        saveWorkforceDetails(sheet, rowIndex, col, emp);
        saveContractIfAny(sheet, rowIndex, col, emp);
        saveSalaryProfileIfAny(sheet, rowIndex, col, emp);
        return false;
    }

    private void saveSalaryProfileIfAny(Sheet sheet, int rowIndex, Map<String, Integer> col, Employee emp) {
        String objRaw = cellString(sheet, rowIndex, col,
                "đối tượng", "đối tượng lương", "loại lương", "nhóm lương", "đối tượng tính lương");
        String blockRaw = cellString(sheet, rowIndex, col, "khối lương", "khối", "khối làm việc");
        String qualRaw = firstNonNullStr(
                cellString(sheet, rowIndex, col, "trình độ", "trình độ đào tạo"),
                cellString(sheet, rowIndex, col, "bằng cấp"));
        String doctorCode = cellString(sheet, rowIndex, col, "mã trình độ bs", "mã bác sỹ", "trình độ bs");
        BigDecimal priorRaise = cellDecimal(sheet, rowIndex, col,
                "thời hạn nâng lương trước", "thâm niên nâng lương trước", "nâng lương trước");
        BigDecimal degreeConv = cellDecimal(sheet, rowIndex, col, "chuyển đổi bằng cấp", "thời gian chuyển đổi bằng cấp");
        BigDecimal attraction = cellDecimal(sheet, rowIndex, col,
                "lương thu hút", "lương thu hút đánh giá cm", "lương thu hút, đánh giá cm");
        String qualNote = cellString(sheet, rowIndex, col, "ghi chú trình độ", "trình độ / ghi chú");

        LocalDate scaleStart = cellDate(sheet, rowIndex, col,
                "thời gian bắt đầu tính thang bảng lương", "thời gian chính thức");
        // Ưu tiên đọc số cache (ô thường là VLOOKUP file ngoài); fallback chuỗi LĐG.
        String seniorityRaw = cellString(sheet, rowIndex, col,
                "thâm niên tính lương tính đến 30/06/2026",
                "thâm niên tính lương tính đến",
                "thâm niên tính lương");
        LocalDate seniorityAsOf = parseSeniorityAsOfFromHeader(col);
        BigDecimal baseSeniority = cellDecimal(sheet, rowIndex, col,
                "thâm niên tính lương tính đến 30/06/2026",
                "thâm niên tính lương tính đến",
                "thâm niên tính lương");
        if (baseSeniority == null) {
            baseSeniority = parseSeniorityYears(seniorityRaw);
        }
        String gradeLabel = cellString(sheet, rowIndex, col, "bậc lương");
        boolean ldg = isLdgValue(seniorityRaw) || isLdgValue(gradeLabel);
        BigDecimal basicSalary = cellDecimal(sheet, rowIndex, col, "lương cơ bản", "lương đóng bh");
        BigDecimal productSalary = cellDecimal(sheet, rowIndex, col, "lương đảm bảo sản phẩm");

        boolean hasSalaryCols = scaleStart != null || baseSeniority != null || ldg
                || basicSalary != null || productSalary != null
                || (objRaw != null && !objRaw.isBlank())
                || (gradeLabel != null && !gradeLabel.isBlank());

        if (!hasSalaryCols
                && (blockRaw == null || blockRaw.isBlank())
                && (qualRaw == null || qualRaw.isBlank())
                && doctorCode == null
                && priorRaise == null
                && degreeConv == null
                && attraction == null) {
            return;
        }

        EmployeeSalaryProfile profile = salaryProfileRepository.findByEmployee(emp).orElse(null);
        SalaryCategory category = parseSalaryCategory(objRaw);
        if (category == null && doctorCode != null && !doctorCode.isBlank()) {
            category = SalaryCategory.DOCTOR;
        }
        if (category == null && qualRaw != null) {
            String dq = DoctorQualifications.normalize(qualRaw);
            if (dq != null && List.of("DK", "DKCT", "CCHN", "CCHNCT", "CK1", "CK2", "NOI_TRU").contains(dq)) {
                category = SalaryCategory.DOCTOR;
            }
        }
        if (category == null && objRaw != null) {
            String t = objRaw.trim().toLowerCase(Locale.ROOT);
            if (t.contains("trực tiếp") || t.contains("truc tiep") || t.contains("gián") || t.contains("gian")) {
                category = SalaryCategory.EMPLOYEE;
            }
        }
        if (profile == null && category == null && !hasSalaryCols) {
            return;
        }
        if (profile == null) {
            profile = EmployeeSalaryProfile.builder()
                    .employee(emp)
                    .salaryCategory(category != null ? category : SalaryCategory.EMPLOYEE)
                    .build();
        } else if (category != null) {
            profile.setSalaryCategory(category);
        } else if (profile.getSalaryCategory() == null) {
            profile.setSalaryCategory(SalaryCategory.EMPLOYEE);
        }
        category = profile.getSalaryCategory();

        if (category == SalaryCategory.EMPLOYEE) {
            EmployeeSalaryBlock block = parseEmployeeBlock(
                    firstNonNullStr(blockRaw, objRaw));
            profile.setEmployeeBlock(block);
            if (qualRaw != null && !qualRaw.isBlank()) {
                profile.setQualification(SalaryQualifications.normalizeQualification(qualRaw));
                profile.setTierGroup(SalaryQualifications.tierGroupFromQualification(profile.getQualification()));
            }
            profile.setDoctorQualificationCode(null);
        } else {
            profile.setEmployeeBlock(null);
            String rawDoctor = doctorCode != null && !doctorCode.isBlank() ? doctorCode : qualRaw;
            String normalizedDoctor = DoctorQualifications.normalize(rawDoctor);
            if (normalizedDoctor != null) {
                profile.setDoctorQualificationCode(normalizedDoctor);
            }
        }
        if (qualNote != null && !qualNote.isBlank()) {
            profile.setQualificationNote(qualNote.trim());
        }
        if (priorRaise != null) {
            profile.setPriorRaiseYears(priorRaise);
        }
        if (degreeConv != null) {
            profile.setDegreeConversionYears(degreeConv);
        }
        if (attraction != null) {
            profile.setProfessionalAttractionSalary(attraction);
        }
        if (scaleStart != null) {
            profile.setSalaryScaleStartDate(scaleStart);
        }
        boolean hasSeniorityCol = col.keySet().stream().anyMatch(k -> {
            String n = stripAccents(k);
            return n.contains("tham nien tinh luong");
        });
        if (ldg) {
            profile.setBaseSeniorityYears(null);
            profile.setSeniorityAsOfDate(null);
        } else if (baseSeniority != null) {
            profile.setBaseSeniorityYears(baseSeniority);
            profile.setSeniorityAsOfDate(
                    seniorityAsOf != null ? seniorityAsOf : LocalDate.of(2026, 6, 30));
        } else if (hasSeniorityCol) {
            // Ô thâm niên trống → không dùng mốc 30/6, tính từ ngày bắt đầu thang.
            profile.setBaseSeniorityYears(null);
            profile.setSeniorityAsOfDate(null);
        }
        profile.setLdg(ldg);
        if (ldg) {
            profile.setFixedGradeLabel("LĐG");
        } else {
            profile.setFixedGradeLabel(null);
        }
        // Lương cơ bản + lương đảm bảo sản phẩm từ Excel (bác sỹ & NV)
        if (basicSalary != null) {
            profile.setImportedInsuranceSalary(basicSalary);
        }
        if (productSalary != null) {
            profile.setImportedProductSalary(productSalary);
        }

        // Đồng bộ SalaryInfo: cơ bản + SP (allowance)
        if (basicSalary != null || productSalary != null) {
            BigDecimal base = basicSalary != null ? basicSalary : BigDecimal.ZERO;
            BigDecimal product = productSalary != null ? productSalary : BigDecimal.ZERO;
            salaryInfoRepository.findByEmployee(emp).ifPresentOrElse(si -> {
                if (basicSalary != null) {
                    si.setBaseSalary(base);
                }
                if (productSalary != null) {
                    si.setAllowance(product);
                }
                salaryInfoRepository.save(si);
            }, () -> salaryInfoRepository.save(SalaryInfo.builder()
                    .employee(emp)
                    .baseSalary(base)
                    .allowance(product)
                    .nextReviewDate(emp.getHireDate() != null ? emp.getHireDate().plusYears(1) : LocalDate.now().plusYears(1))
                    .build()));
        }

        salaryProfileRepository.save(profile);
    }

    private static LocalDate parseSeniorityAsOfFromHeader(Map<String, Integer> col) {
        for (String key : col.keySet()) {
            // "thâm niên tính lương tính đến 30/06/2026"
            java.util.regex.Matcher m = java.util.regex.Pattern
                    .compile("tinh den\\s*(\\d{1,2})[/.-](\\d{1,2})[/.-](\\d{4})", java.util.regex.Pattern.CASE_INSENSITIVE)
                    .matcher(stripAccents(key));
            if (m.find()) {
                try {
                    int d = Integer.parseInt(m.group(1));
                    int mo = Integer.parseInt(m.group(2));
                    int y = Integer.parseInt(m.group(3));
                    return LocalDate.of(y, mo, d);
                } catch (Exception ignored) {
                }
            }
        }
        return null;
    }

    private static boolean isLdgValue(String raw) {
        if (raw == null || raw.isBlank()) {
            return false;
        }
        String t = stripAccents(raw).replaceAll("\\s+", "");
        return t.equals("ldg") || t.startsWith("ldg");
    }

    private static BigDecimal parseSeniorityYears(String raw) {
        if (raw == null || raw.isBlank() || isLdgValue(raw) || looksLikeFormulaText(raw)) {
            return null;
        }
        try {
            String n = raw.replaceAll("[^0-9.,\\-]", "").replace(",", ".");
            if (n.isBlank() || n.equals("-") || n.equals(".") || n.chars().filter(ch -> ch == '.').count() > 1) {
                return null;
            }
            BigDecimal v = new BigDecimal(n);
            // Thâm niên hợp lệ thường < 80 năm — tránh nuốt số linh tinh từ chuỗi công thức.
            if (v.compareTo(BigDecimal.ZERO) < 0 || v.compareTo(BigDecimal.valueOf(80)) > 0) {
                return null;
            }
            return v;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static EmploymentType parseEmploymentType(String raw, EmploymentType fallback) {
        if (raw == null || raw.isBlank()) {
            return fallback != null ? fallback : EmploymentType.FULL_TIME;
        }
        String t = stripAccents(raw).replaceAll("\\s+", "");
        if (t.contains("btg") || t.contains("banthoigian") || t.contains("parttime") || t.contains("part")) {
            return EmploymentType.PART_TIME;
        }
        return EmploymentType.FULL_TIME;
    }

    private String generatePartTimeCode(String fullName, LocalDate dob) {
        String suffix;
        if (dob != null) {
            suffix = dob.format(DateTimeFormatter.ofPattern("ddMMyyyy"));
        } else {
            suffix = Integer.toHexString(Math.abs(fullName.hashCode())).toUpperCase(Locale.ROOT);
            if (suffix.length() > 8) {
                suffix = suffix.substring(0, 8);
            }
        }
        String base = "BTG-" + suffix;
        String code = base;
        int i = 0;
        while (employeeRepository.existsByEmployeeCode(code)) {
            code = base + "-" + (++i);
        }
        return code;
    }

    private static SalaryCategory parseSalaryCategory(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String t = raw.trim().toLowerCase(Locale.ROOT);
        if (t.contains("bác") || t.contains("bac") || t.contains("bs") || t.contains("doctor")) {
            return SalaryCategory.DOCTOR;
        }
        if (t.contains("nhân viên") || t.contains("nhan vien") || t.contains("employee")
                || t.contains("trực tiếp") || t.contains("truc tiep")
                || t.contains("gián") || t.contains("gian")) {
            return SalaryCategory.EMPLOYEE;
        }
        return null;
    }

    private static EmployeeSalaryBlock parseEmployeeBlock(String raw) {
        if (raw == null || raw.isBlank()) {
            return EmployeeSalaryBlock.DIRECT;
        }
        String t = raw.trim().toLowerCase(Locale.ROOT);
        if (t.contains("gián") || t.contains("gian")) {
            return EmployeeSalaryBlock.INDIRECT;
        }
        return EmployeeSalaryBlock.DIRECT;
    }

    private BigDecimal cellDecimal(Sheet sheet, int rowIndex, Map<String, Integer> col, String... keys) {
        int idx = resolveCol(col, keys);
        if (idx < 0) {
            return null;
        }
        Cell cell = getEffectiveCell(sheet, rowIndex, idx);
        if (cell == null || cell.getCellType() == CellType.BLANK) {
            return null;
        }
        try {
            if (cell.getCellType() == CellType.NUMERIC && !DateUtil.isCellDateFormatted(cell)) {
                return BigDecimal.valueOf(cell.getNumericCellValue()).stripTrailingZeros();
            }
            if (cell.getCellType() == CellType.FORMULA) {
                try {
                    return BigDecimal.valueOf(cell.getNumericCellValue()).stripTrailingZeros();
                } catch (Exception ignored) {
                }
            }
        } catch (Exception ignored) {
        }
        String s = formatCellCached(cell);
        if (s == null || s.isBlank()) {
            return null;
        }
        try {
            String n = s.replaceAll("[^0-9.,\\-]", "").replace(",", ".");
            if (n.isBlank()) {
                return null;
            }
            return new BigDecimal(n);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private void saveWorkforceDetails(Sheet sheet, int rowIndex, Map<String, Integer> col, Employee emp) {
        EmployeeWorkforceDetails d = workforceDetailsRepository.findByEmployee(emp).orElse(
                EmployeeWorkforceDetails.builder().employee(emp).build());

        d.setPayrollDisplayName(trimToNull(cellString(sheet, rowIndex, col, "họ tên trên bảng lương")));
        d.setDuplicateCheckFlag(null);
        d.setTenureText(null);
        d.setIdCardIssueDate(cellDate(sheet, rowIndex, col, "ngày cấp"));
        d.setSpecialty(trimToNull(cellString(sheet, rowIndex, col, "chuyên ngành/ chuyên môn", "chuyên ngành chuyên môn")));
        d.setDegree(trimToNull(cellString(sheet, rowIndex, col, "bằng cấp")));
        d.setBankAccount(trimToNull(cellString(sheet, rowIndex, col, "stk đăng ký nhận lương")));
        d.setBankName(trimToNull(cellString(sheet, rowIndex, col, "ngân hàng đăng ký nhận lương")));
        String[] org = readOrgColumns(sheet, rowIndex, col);
        d.setWorkUnitDetail(trimToNull(org[1]));
        d.setInsuranceParticipation(trimToNull(cellString(sheet, rowIndex, col, "tham gia bảo hiểm")));
        d.setWorkforceNotes(trimToNull(cellString(sheet, rowIndex, col, "ghi chú")));
        d.setProbationStartDate(cellDate(sheet, rowIndex, col, "ngày thử việc"));
        d.setOfficialStartDate(cellDate(sheet, rowIndex, col, "ngày chính thức"));
        d.setContractNumber(trimToNull(cellString(sheet, rowIndex, col, "số hợp đồng")));
        d.setContractSignDate(cellDate(sheet, rowIndex, col, "ngày ký hđ"));
        d.setContractTerm(trimToNull(cellString(sheet, rowIndex, col, "thời hạn hợp đồng")));
        d.setSocialInsuranceBook(trimToNull(cellString(sheet, rowIndex, col, "số sổ bh")));
        d.setAttendanceCode(trimToNull(cellString(sheet, rowIndex, col, "mã chấm công", "ma cham cong")));
        d.setPracticeCertNumber(trimToNull(cellString(sheet, rowIndex, col, "số cchn")));
        d.setPracticeCertDateRaw(trimToNull(cellString(sheet, rowIndex, col, "ngày cấp cchn")));
        d.setProfessionalDiploma(trimToNull(cellString(sheet, rowIndex, col, "văn bằng chuyên môn")));
        d.setPracticeScope(trimToNull(cellString(sheet, rowIndex, col, "phạm vi hành nghề")));
        d.setOtherTrainingCertificates(trimToNull(cellString(sheet, rowIndex, col, "chứng chỉ đào tạo khác")));
        d.setCki(trimToNull(cellString(sheet, rowIndex, col, "cki")));
        d.setDependentsInfo(trimToNull(cellString(sheet, rowIndex, col, "thông tin người phụ thuộc")));
        d.setEthnicity(trimToNull(cellString(sheet, rowIndex, col, "dân tộc")));
        d.setPlaceOfOrigin(trimToNull(cellString(sheet, rowIndex, col, "nguyên quán", "nguyen quan")));
        d.setMaritalStatus(trimToNull(cellString(sheet, rowIndex, col, "hôn nhân", "tình trạng hôn nhân", "tinh trang hon nhan")));
        d.setBloodType(trimToNull(cellString(sheet, rowIndex, col, "nhóm máu", "nhom mau")));
        d.setEmergencyContact(trimToNull(cellString(sheet, rowIndex, col, "liên hệ khẩn cấp", "người liên hệ khẩn cấp", "lien he khan cap")));
        d.setEmergencyPhone(trimToNull(cellString(sheet, rowIndex, col, "đt liên hệ khẩn cấp", "điện thoại liên hệ khẩn cấp", "sdt lien he khan cap")));

        workforceDetailsRepository.save(d);

        String workUnit = trimToNull(d.getWorkUnitDetail());
        if (workUnit != null && emp.getDepartment() != null) {
            departmentWorkUnitService.findOrCreate(emp.getDepartment(), workUnit);
        }
    }

    private void saveContractIfAny(Sheet sheet, int rowIndex, Map<String, Integer> col, Employee emp) {
        String num = cellString(sheet, rowIndex, col, "số hợp đồng");
        LocalDate sign = cellDate(sheet, rowIndex, col, "ngày ký hđ");
        String term = cellString(sheet, rowIndex, col, "thời hạn hợp đồng");
        if ((num == null || num.isBlank()) && sign == null && (term == null || term.isBlank())) {
            return;
        }
        if (num != null && !num.isBlank()) {
            List<Contract> existing = contractRepository.findByEmployeeOrderByStartDateDesc(emp);
            boolean dup = existing.stream().anyMatch(c -> num.equals(c.getContractType()));
            if (dup) {
                return;
            }
        }
        contractRepository.save(Contract.builder()
                .employee(emp)
                .contractType(num != null && !num.isBlank() ? num : "Hợp đồng lao động")
                .startDate(sign != null ? sign : emp.getHireDate())
                .endDate(null)
                .note(term)
                .build());
    }

    private void syncImportedPhoneLogin(Employee emp) {
        if (emp == null || emp.getPhone() == null || emp.getPhone().isBlank() || emp.getUser() == null) {
            return;
        }
        try {
            employeeService.syncPhoneAndLoginUsername(emp, emp.getPhone());
        } catch (ApiException ex) {
            // Không chặn cả file import vì 1 dòng trùng SĐT — giữ phone đã ghi, username cũ.
            log.warn("Không đồng bộ TK đăng nhập theo SĐT NV {}: {}", emp.getId(), ex.getMessage());
        }
    }

    private static void mergeStringField(
            java.util.function.Supplier<String> getter,
            java.util.function.Consumer<String> setter,
            String incoming) {
        String v = trimToNull(incoming);
        if (v != null) {
            setter.accept(v);
        }
    }

    private Department findOrCreateDepartment(String unitName) {
        if (unitName == null || unitName.isBlank()) {
            return departmentRepository.findByCode("CHUNG").orElseGet(() ->
                    departmentRepository.save(Department.builder().code("CHUNG").name("Chưa phân đơn vị").build()));
        }
        String name = canonicalizeDepartmentName(unitName);
        if (name == null || name.isBlank()) {
            name = unitName.trim();
        }
        Optional<Department> exact = departmentRepository.findFirstByNameIgnoreCaseOrderByIdAsc(name);
        if (exact.isPresent()) {
            return exact.get();
        }
        // Gộp với phòng ban đã có nhưng khác chữ (Khoa HSCC ↔ KHOA HỒI SỨC CẤP CỨU)
        String needle = orgKey(name);
        if (!needle.isEmpty()) {
            for (Department existing : departmentRepository.findAll()) {
                String existingCanonical = canonicalizeDepartmentName(existing.getName());
                if (needle.equals(orgKey(existing.getName())) || needle.equals(orgKey(existingCanonical))) {
                    // Đổi tên về chuẩn Excel nếu đang là alias
                    if (existingCanonical != null && !existingCanonical.equalsIgnoreCase(existing.getName())
                            && CANONICAL_DEPARTMENTS.stream().anyMatch(c -> c.equalsIgnoreCase(existingCanonical))) {
                        existing.setName(existingCanonical);
                        return departmentRepository.save(existing);
                    }
                    return existing;
                }
            }
        }
        String code = buildUniqueDeptCode(name);
        return departmentRepository.save(Department.builder().code(code).name(name).build());
    }

    private Position findOrCreatePosition(String title) {
        if (title == null || title.isBlank()) {
            return positionRepository.findFirstByTitleIgnoreCaseOrderByIdAsc("Nhân viên")
                    .or(() -> positionRepository.findByCode("NV"))
                    .orElseGet(() -> positionRepository.save(
                            Position.builder().code("NV").title("Nhân viên").levelRank(1).build()));
        }
        String t = canonicalPositionTitle(title);
        return positionRepository.findFirstByTitleIgnoreCaseOrderByIdAsc(t).orElseGet(() -> {
            String code = buildUniquePosCode(t);
            return positionRepository.save(Position.builder().code(code).title(t).levelRank(2).build());
        });
    }

    private static String canonicalPositionTitle(String title) {
        String trimmed = title.trim();
        if ("Nhân viên hành chính".equalsIgnoreCase(trimmed)) {
            return "Nhân viên";
        }
        String folded = foldAscii(trimmed);
        if ("bac si".equals(folded) || "bac sy".equals(folded)) {
            return "Bác sĩ";
        }
        return trimmed;
    }

    /** Bỏ dấu tiếng Việt để so khớp biến thể chính tả chức vụ. */
    private static String foldAscii(String value) {
        return java.text.Normalizer.normalize(value == null ? "" : value, java.text.Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .toLowerCase(Locale.ROOT)
                .replace('đ', 'd')
                .trim();
    }

    private String buildUniqueDeptCode(String name) {
        String base = "D" + Integer.toHexString(Math.abs(name.hashCode())).toUpperCase(Locale.ROOT);
        String code = base.length() > 32 ? base.substring(0, 32) : base;
        String c = code;
        int i = 0;
        while (departmentRepository.existsByCode(c)) {
            c = (base.length() > 28 ? base.substring(0, 28) : base) + (++i);
        }
        return c;
    }

    private String buildUniquePosCode(String title) {
        String base = "P" + Integer.toHexString(Math.abs(title.hashCode())).toUpperCase(Locale.ROOT);
        String code = base.length() > 32 ? base.substring(0, 32) : base;
        String c = code;
        int i = 0;
        while (positionRepository.existsByCode(c)) {
            c = (base.length() > 28 ? base.substring(0, 28) : base) + (++i);
        }
        return c;
    }

    /**
     * Giữ tên miền gốc khi có thể: nếu email từ file trùng, thêm hậu tố theo mã NV (vd. tên.mã@domain)
     * thay vì thay bằng @import — trừ khi cả biến thể vẫn trùng.
     */
    private String ensureUniqueEmail(String email, String employeeCode) {
        if (!userAccountRepository.existsByEmail(email)) {
            return email;
        }
        int at = email.indexOf('@');
        if (at > 0 && at < email.length() - 1) {
            String local = email.substring(0, at);
            String domain = email.substring(at + 1);
            String emp = sanitizeUsername(employeeCode);
            for (int n = 0; n < 200; n++) {
                String tag = n == 0 ? ("." + emp) : ("." + emp + n);
                String candidate = local + tag + "@" + domain;
                if (!userAccountRepository.existsByEmail(candidate)) {
                    return candidate;
                }
            }
        }
        String e = "nv_" + sanitizeUsername(employeeCode) + "@import.minhan.vn";
        int i = 0;
        while (userAccountRepository.existsByEmail(e)) {
            e = "nv_" + sanitizeUsername(employeeCode) + "_" + (++i) + "@import.minhan.vn";
        }
        return e;
    }

    private static String sanitizeUsername(String code) {
        return EmployeeAccountProvisioner.sanitizeUsername(code);
    }

    private static String trimToNull(String s) {
        if (s == null) {
            return null;
        }
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    @SafeVarargs
    private static <T> T firstNonNull(T... vals) {
        for (T v : vals) {
            if (v != null) {
                return v;
            }
        }
        return null;
    }

    private static String firstNonNullStr(String... vals) {
        for (String v : vals) {
            String t = trimToNull(v);
            if (t != null) {
                return t;
            }
        }
        return null;
    }

    private Map<String, Integer> buildHeaderMap(Row headerRow) {
        Map<String, Integer> map = new HashMap<>();
        short last = headerRow.getLastCellNum();
        for (int c = 0; c < last; c++) {
            Cell cell = headerRow.getCell(c);
            String raw = FORMATTER.formatCellValue(cell).trim();
            if (raw.isEmpty()) {
                continue;
            }
            String key = normalizeHeader(raw);
            map.put(key, c);
        }
        return map;
    }

    private static String normalizeHeader(String s) {
        return stripAccents(s)
                .replace('\u00A0', ' ')
                .replaceAll("\\s+", " ")
                .trim();
    }

    private int resolveCol(Map<String, Integer> col, String... aliases) {
        for (String a : aliases) {
            String k = normalizeHeader(a);
            if (col.containsKey(k)) {
                return col.get(k);
            }
        }
        for (String a : aliases) {
            String sub = normalizeHeader(a);
            for (Map.Entry<String, Integer> e : col.entrySet()) {
                if (e.getKey().contains(sub) || sub.contains(e.getKey())) {
                    return e.getValue();
                }
            }
        }
        return -1;
    }

    /**
     * Ô bị gộp (merge) theo Excel chỉ lưu giá trị ở góc trên-trái; POI trả về rỗng ở các dòng còn lại.
     * Lấy giá trị từ ô mỏ neo của vùng gộp nếu (row, col) nằm trong vùng đó.
     */
    private Cell getEffectiveCell(Sheet sheet, int rowIndex, int columnIndex) {
        for (int i = 0; i < sheet.getNumMergedRegions(); i++) {
            CellRangeAddress range = sheet.getMergedRegion(i);
            if (range.isInRange(rowIndex, columnIndex)) {
                Row firstRow = sheet.getRow(range.getFirstRow());
                if (firstRow == null) {
                    return null;
                }
                return firstRow.getCell(range.getFirstColumn());
            }
        }
        Row row = sheet.getRow(rowIndex);
        if (row == null) {
            return null;
        }
        return row.getCell(columnIndex);
    }

    private String cellString(Sheet sheet, int rowIndex, Map<String, Integer> col, String... headerAliases) {
        int idx = resolveCol(col, headerAliases);
        if (idx < 0) {
            return null;
        }
        Cell cell = getEffectiveCell(sheet, rowIndex, idx);
        if (cell == null) {
            return null;
        }
        String v = formatCellCached(cell);
        return v == null || v.isEmpty() ? null : v;
    }

    private LocalDate cellDate(Sheet sheet, int rowIndex, Map<String, Integer> col, String... headerAliases) {
        int idx = resolveCol(col, headerAliases);
        if (idx < 0) {
            return null;
        }
        Cell cell = getEffectiveCell(sheet, rowIndex, idx);
        if (cell == null || cell.getCellType() == CellType.BLANK) {
            return null;
        }
        try {
            if (cell.getCellType() == CellType.NUMERIC && DateUtil.isCellDateFormatted(cell)) {
                return cell.getDateCellValue().toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
            }
            if (cell.getCellType() == CellType.FORMULA
                    && cell.getCachedFormulaResultType() == CellType.NUMERIC
                    && DateUtil.isCellDateFormatted(cell)) {
                return cell.getDateCellValue().toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
            }
            if (cell.getCellType() == CellType.FORMULA
                    && cell.getCachedFormulaResultType() == CellType.NUMERIC) {
                double n = cell.getNumericCellValue();
                // Excel serial date roughly 20000–60000 for modern dates
                if (n > 20000 && n < 80000) {
                    return DateUtil.getLocalDateTime(n).toLocalDate();
                }
            }
        } catch (Exception ignored) {
        }
        String s = formatCellCached(cell);
        if (s == null || s.isEmpty()) {
            return null;
        }
        // Bỏ phần giờ nếu có
        if (s.contains(" ")) {
            s = s.split("\\s+")[0];
        }
        List<DateTimeFormatter> fmts = List.of(
                DateTimeFormatter.ofPattern("d/M/yyyy"),
                DateTimeFormatter.ofPattern("dd/MM/yyyy"),
                DateTimeFormatter.ofPattern("M/d/yy"),
                DateTimeFormatter.ofPattern("M/d/yyyy"),
                DateTimeFormatter.ISO_LOCAL_DATE
        );
        for (DateTimeFormatter f : fmts) {
            try {
                return LocalDate.parse(s, f);
            } catch (DateTimeParseException ignored) {
            }
        }
        return null;
    }

    /** Đọc giá trị ô — ưu tiên kết quả công thức đã cache (VLOOKUP external). */
    private static String formatCellCached(Cell cell) {
        if (cell == null) {
            return null;
        }
        try {
            if (cell.getCellType() == CellType.FORMULA) {
                switch (cell.getCachedFormulaResultType()) {
                    case NUMERIC -> {
                        if (DateUtil.isCellDateFormatted(cell)) {
                            return cell.getLocalDateTimeCellValue().toLocalDate()
                                    .format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
                        }
                        // DataFormatter với VLOOKUP file ngoài thường trả về chuỗi công thức thô
                        // (+VLOOKUP...) thay vì số cache — luôn lấy numeric cache.
                        double n = cell.getNumericCellValue();
                        String formatted = FORMATTER.formatCellValue(cell).trim();
                        if (!looksLikeFormulaText(formatted)
                                && !formatted.isEmpty()
                                && !formatted.matches("(?i).*e[+-]?\\d+.*")) {
                            return formatted;
                        }
                        if (n == Math.rint(n) && Math.abs(n) < 1e15) {
                            return BigDecimal.valueOf(n).toPlainString();
                        }
                        return BigDecimal.valueOf(n).stripTrailingZeros().toPlainString();
                    }
                    case STRING -> {
                        String s = cell.getRichStringCellValue().getString();
                        return s != null ? s.trim() : null;
                    }
                    case BOOLEAN -> {
                        return String.valueOf(cell.getBooleanCellValue());
                    }
                    case ERROR -> {
                        return null;
                    }
                    default -> {
                        return null;
                    }
                }
            }
            if (cell.getCellType() == CellType.NUMERIC) {
                if (DateUtil.isCellDateFormatted(cell)) {
                    return cell.getLocalDateTimeCellValue().toLocalDate()
                            .format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
                }
                // Quan trọng: dùng DataFormatter để giữ 0 đầu theo number format Excel
                String formatted = FORMATTER.formatCellValue(cell).trim();
                if (!formatted.isEmpty() && !formatted.matches("(?i).*e[+-]?\\d+.*")) {
                    return formatted;
                }
                double n = cell.getNumericCellValue();
                if (n == Math.rint(n) && Math.abs(n) < 1e15) {
                    return BigDecimal.valueOf((long) n).toPlainString();
                }
                return BigDecimal.valueOf(n).stripTrailingZeros().toPlainString();
            }
        } catch (Exception ignored) {
        }
        String v = FORMATTER.formatCellValue(cell).trim();
        // Bỏ công thức thô nếu formatter trả về chuỗi bắt đầu bằng =
        if (looksLikeFormulaText(v)) {
            return null;
        }
        return v.isEmpty() ? null : v;
    }

    /** Chuỗi công thức thô (DataFormatter không resolve được VLOOKUP external). */
    private static boolean looksLikeFormulaText(String v) {
        if (v == null || v.isBlank()) {
            return false;
        }
        String t = v.trim();
        if (t.startsWith("=") || t.startsWith("+") || t.startsWith("-(")) {
            return true;
        }
        String u = t.toUpperCase(Locale.ROOT);
        return u.contains("VLOOKUP(") || u.contains("XLOOKUP(") || u.contains("INDEX(");
    }
}
