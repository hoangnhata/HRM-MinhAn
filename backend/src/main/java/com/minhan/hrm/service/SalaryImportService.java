package com.minhan.hrm.service;

import com.minhan.hrm.dto.salary.SalaryImportResultDto;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeSalaryProfileRepository;
import com.minhan.hrm.repository.SalaryScaleDoctorEntryRepository;
import com.minhan.hrm.repository.SalaryScaleEntryRepository;
import com.minhan.hrm.salary.SalaryAmounts;
import com.minhan.hrm.salary.SalaryQualifications;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.Date;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
@Slf4j
public class SalaryImportService {

    private static final DataFormatter FORMATTER = new DataFormatter(Locale.forLanguageTag("vi-VN"));
    private static final Pattern GRADE_NUM = Pattern.compile("(\\d+)");
    private static final Pattern AS_OF_DATE = Pattern.compile(
            "T[ÍI]NH\\s+Đ[ẾE]N\\s+(\\d{1,2}/\\d{1,2}/\\d{4})",
            Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);

    private final EmployeeRepository employeeRepository;
    private final EmployeeSalaryProfileRepository profileRepository;
    private final SalaryScaleEntryRepository scaleEntryRepository;
    private final SalaryScaleDoctorEntryRepository doctorEntryRepository;
    private final SalaryCalculatorService salaryCalculator;

    @Transactional
    public SalaryImportResultDto importSeniorityExcel(MultipartFile file) {
        validateXlsx(file);
        int total = 0;
        int success = 0;
        int notFound = 0;
        List<Map<String, Object>> errors = new ArrayList<>();
        List<Map<String, Object>> warnings = new ArrayList<>();

        try (InputStream in = file.getInputStream(); Workbook wb = new XSSFWorkbook(in)) {
            Sheet sheet = wb.getSheet("nv");
            if (sheet == null) {
                sheet = wb.getSheetAt(0);
            }
            int headerRow = findHeaderRow(sheet, "họ và tên");
            if (headerRow < 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Không tìm thấy dòng tiêu đề (Họ và tên)");
            }
            Map<String, Integer> col = buildSeniorityHeaderMap(sheet, headerRow);
            LocalDate seniorityAsOf = extractSeniorityAsOfDate(sheet);
            for (int r = headerRow + 1; r <= sheet.getLastRowNum(); r++) {
                Row row = sheet.getRow(r);
                if (row == null || isEmptyDataRow(row, col)) {
                    continue;
                }
                String name = cellString(row, col, "họ và tên");
                if (name == null || name.isBlank()) {
                    continue;
                }
                if (looksLikeSectionHeader(name)) {
                    continue;
                }
                total++;
                try {
                    Optional<Employee> empOpt = matchEmployee(row, col);
                    if (empOpt.isEmpty()) {
                        notFound++;
                        errors.add(Map.of("row", r + 1, "message", "Không tìm thấy nhân viên: " + name.trim()));
                        continue;
                    }
                    Employee emp = empOpt.get();
                    upsertFromSeniorityRow(emp, row, col, warnings, r + 1, seniorityAsOf);
                    success++;
                } catch (Exception ex) {
                    errors.add(Map.of("row", r + 1, "message", ex.getMessage() != null ? ex.getMessage() : "Lỗi"));
                }
            }
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.error("Import thâm niên lỗi", e);
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đọc được file: " + e.getMessage());
        }
        return SalaryImportResultDto.builder()
                .totalRows(total)
                .successCount(success)
                .updatedCount(success)
                .notFoundCount(notFound)
                .errorCount(errors.size())
                .warnings(warnings)
                .errors(errors)
                .build();
    }

    @Transactional
    public SalaryImportResultDto importScaleExcel(MultipartFile file) {
        validateXlsx(file);
        int total = 0;
        int created = 0;
        int updated = 0;
        List<Map<String, Object>> errors = new ArrayList<>();

        try (InputStream in = file.getInputStream(); Workbook wb = new XSSFWorkbook(in)) {
            Sheet nvSheet = wb.getSheet("THANG BẢNG LƯƠNG CHỐT");
            if (nvSheet != null) {
                int[] counts = importNvScaleBlock(nvSheet, SalaryScaleType.EMPLOYEE_DIRECT, "TRỰC TIẾP", errors);
                total += counts[0];
                created += counts[1];
                updated += counts[2];
                counts = importNvScaleBlock(nvSheet, SalaryScaleType.EMPLOYEE_INDIRECT, "GIÁN TIẾP", errors);
                total += counts[0];
                created += counts[1];
                updated += counts[2];
            }
            Sheet bsSheet = wb.getSheet("thang bảng lương bs");
            if (bsSheet != null) {
                int[] bs = importDoctorScaleSheet(bsSheet, errors);
                total += bs[0];
                created += bs[1];
                updated += bs[2];
            }
            if (total == 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Không đọc được dữ liệu thang lương (cần sheet THANG BẢNG LƯƠNG CHỐT hoặc thang bảng lương bs)");
            }
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.error("Import thang lương lỗi", e);
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đọc được file: " + e.getMessage());
        }
        return SalaryImportResultDto.builder()
                .totalRows(total)
                .successCount(created + updated)
                .createdCount(created)
                .updatedCount(updated)
                .errorCount(errors.size())
                .errors(errors)
                .build();
    }

    private int[] importNvScaleBlock(
            Sheet sheet, SalaryScaleType scaleType, String blockKeyword, List<Map<String, Object>> errors) {
        int total = 0;
        int created = 0;
        int updated = 0;
        int blockStart = -1;
        for (int r = 0; r <= sheet.getLastRowNum(); r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                continue;
            }
            String a = cellRaw(row, 0);
            if (a != null && a.toUpperCase(Locale.ROOT).contains(blockKeyword)
                    && a.toUpperCase(Locale.ROOT).contains("THANG")) {
                blockStart = r;
                break;
            }
        }
        if (blockStart < 0) {
            return new int[] {0, 0, 0};
        }
        int headerRow = -1;
        for (int r = blockStart; r <= Math.min(blockStart + 5, sheet.getLastRowNum()); r++) {
            Row row = sheet.getRow(r);
            if (row != null && rowCellContains(row, 3, "BẬC 1")) {
                headerRow = r;
                break;
            }
        }
        if (headerRow < 0) {
            return new int[] {0, 0, 0};
        }
        int r = headerRow + 1;
        while (r <= sheet.getLastRowNum()) {
            Row row = sheet.getRow(r);
            if (row == null) {
                r++;
                continue;
            }
            if (cellRaw(row, 0) != null && cellRaw(row, 0).toUpperCase(Locale.ROOT).contains("THANG")) {
                break;
            }
            String qual = cellRaw(row, 1);
            String content = cellRaw(row, 2);
            if (qual != null && content != null) {
                qual = SalaryQualifications.normalizeQualification(qual);
                try {
                    if (content.toLowerCase(Locale.ROOT).contains("hệ số")) {
                        BigDecimal[] coefs = readGradeAmounts(row, 3, 10);
                        BigDecimal[] insurance = findScaleAmountRow(sheet, r + 1, "lương cơ bản", "mức lương");
                        BigDecimal[] product = findScaleAmountRow(sheet, r + 1, "đảm bảo sản phẩm");
                        BigDecimal[] totals = findScaleAmountRow(sheet, r + 1, "tổng thu nhập", "tổng lương");
                        if (insurance == null || product == null || totals == null) {
                            r++;
                            continue;
                        }
                        int nextRow = r + 1;
                        while (nextRow <= sheet.getLastRowNum()) {
                            Row scan = sheet.getRow(nextRow);
                            String label = scan != null ? cellRaw(scan, 2) : null;
                            if (label != null && label.toLowerCase(Locale.ROOT).contains("hệ số")) {
                                break;
                            }
                            if (scan != null && cellRaw(scan, 1) != null && !cellRaw(scan, 1).isBlank()) {
                                break;
                            }
                            nextRow++;
                        }
                        r = nextRow;
                        for (int g = 1; g <= 10; g++) {
                            int idx = g - 1;
                            boolean isNew = upsertScaleEntry(
                                    scaleType, qual, g, coefs[idx], insurance[idx], product[idx], totals[idx]);
                            total++;
                            if (isNew) {
                                created++;
                            } else {
                                updated++;
                            }
                        }
                        continue;
                    }
                } catch (Exception ex) {
                    errors.add(Map.of("row", r + 1, "message", ex.getMessage()));
                }
            }
            r++;
        }
        return new int[] {total, created, updated};
    }

    private boolean upsertScaleEntry(
            SalaryScaleType scaleType,
            String qualification,
            int grade,
            BigDecimal coefficient,
            BigDecimal insurance,
            BigDecimal product,
            BigDecimal total) {
        if (coefficient == null || insurance == null || product == null || total == null) {
            return false;
        }
        Optional<SalaryScaleEntry> existing = scaleEntryRepository.findByScaleTypeAndQualificationAndGradeLevel(
                scaleType, qualification, grade);
        BigDecimal from = BigDecimal.valueOf((grade - 1) * 2L);
        BigDecimal to = grade >= 10 ? null : BigDecimal.valueOf(grade * 2L);
        SalaryScaleEntry entry = existing.orElseGet(() -> SalaryScaleEntry.builder()
                .scaleType(scaleType)
                .qualification(qualification)
                .gradeLevel(grade)
                .build());
        boolean isNew = existing.isEmpty();
        entry.setSeniorityFrom(from);
        entry.setSeniorityTo(to);
        entry.setCoefficient(coefficient);
        entry.setBaseInsuranceSalary(insurance.setScale(0, RoundingMode.HALF_UP));
        entry.setProductSalary(product.setScale(0, RoundingMode.HALF_UP));
        entry.setTotalIncome(total.setScale(0, RoundingMode.HALF_UP));
        scaleEntryRepository.save(entry);
        return isNew;
    }

    private int[] importDoctorScaleSheet(Sheet sheet, List<Map<String, Object>> errors) {
        int total = 0;
        int created = 0;
        int updated = 0;
        Row header = sheet.getRow(0);
        if (header == null) {
            return new int[] {0, 0, 0};
        }
        for (int r = 1; r <= sheet.getLastRowNum(); r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                continue;
            }
            String code = cellRaw(row, 0);
            String name = cellRaw(row, 1);
            String timeLabel = cellRaw(row, 3);
            BigDecimal salaryAmount = parseMoney(cellRaw(row, 5));
            if (code == null || salaryAmount == null) {
                continue;
            }
            total++;
            try {
                String qualCode = code.replaceAll("\\d.*", "").trim();
                if (qualCode.isEmpty()) {
                    qualCode = code;
                }
                final String qualCodeFinal = qualCode;
                final String timeLabelFinal = timeLabel != null ? timeLabel : "";
                final int sortOrder = r;
                BigDecimal[] range = parseTimeRange(timeLabelFinal.isEmpty() ? cellRaw(row, 4) : timeLabelFinal);
                Optional<SalaryScaleDoctorEntry> existing = doctorEntryRepository.findAllByOrderBySortOrderAsc()
                        .stream()
                        .filter(e -> e.getQualificationCode().equalsIgnoreCase(qualCodeFinal)
                                && e.getTimeLabel().equalsIgnoreCase(timeLabelFinal))
                        .findFirst();
                SalaryScaleDoctorEntry e = existing.orElseGet(() -> SalaryScaleDoctorEntry.builder()
                        .qualificationCode(qualCodeFinal.toUpperCase(Locale.ROOT))
                        .qualificationName(name != null ? name : qualCodeFinal)
                        .timeLabel(timeLabelFinal)
                        .sortOrder(sortOrder)
                        .build());
                boolean isNew = existing.isEmpty();
                e.setYearsMin(range[0]);
                e.setYearsMax(range[1]);
                e.setTotalSalary(salaryAmount);
                doctorEntryRepository.save(e);
                if (isNew) {
                    created++;
                } else {
                    updated++;
                }
            } catch (Exception ex) {
                errors.add(Map.of("row", r + 1, "message", ex.getMessage()));
            }
        }
        return new int[] {total, created, updated};
    }

    private void upsertFromSeniorityRow(
            Employee emp,
            Row row,
            Map<String, Integer> col,
            List<Map<String, Object>> warnings,
            int rowNum,
            LocalDate seniorityAsOf) {
        EmployeeSalaryProfile profile = profileRepository.findByEmployee(emp).orElseGet(() ->
                EmployeeSalaryProfile.builder()
                        .employee(emp)
                        .salaryCategory(SalaryCategory.EMPLOYEE)
                        .build());

        String blockRaw = cellString(row, col, "đối tượng");
        if (blockRaw != null) {
            profile.setEmployeeBlock(parseBlock(blockRaw));
            profile.setSalaryCategory(SalaryCategory.EMPLOYEE);
        }

        String qual = cellString(row, col, "trình độ");
        if (qual != null && !qual.isBlank()) {
            profile.setQualification(SalaryQualifications.normalizeQualification(qual));
            profile.setTierGroup(SalaryQualifications.tierGroupFromQualification(profile.getQualification()));
        }

        LocalDate join = cellDate(row, col, "thời gian vào minh an làm", "ngày vào làm");
        if (join != null) {
            emp.setHireDate(join);
            employeeRepository.save(emp);
        }

        if (seniorityAsOf != null) {
            profile.setSeniorityAsOfDate(seniorityAsOf);
        }

        BigDecimal adjustedYears = cellDecimal(
                row, col, "số năm công tác chỉ tính cho số tháng từ 13 công trở lên", "số năm công tác");
        BigDecimal seniorityExcel = cellDecimal(row, col, "thâm niên tính lương");
        BigDecimal bonus6Months = cellDecimal(
                row, col, "cộng 6 tháng cho nhân viên xuất sắc 2022, 2023", "cộng 6 tháng");
        BigDecimal bonus1Year = cellDecimal(
                row, col, "cộng 1 năm cho nhân viên xuất sắc năm 2024", "cộng 1 năm");
        BigDecimal prior = sumDecimals(bonus6Months, bonus1Year);
        if (prior.compareTo(BigDecimal.ZERO) == 0 && seniorityExcel != null && adjustedYears != null) {
            prior = seniorityExcel.subtract(adjustedYears);
            if (prior.compareTo(BigDecimal.ZERO) < 0) {
                prior = BigDecimal.ZERO;
            }
        }
        profile.setPriorRaiseYears(prior);

        BigDecimal insuranceSalary = readSeniorityMoney(row, col, "lương đóng bh", "lương cơ bản");
        BigDecimal productSalary = readSeniorityMoney(row, col, "lương đảm bảo sản phẩm");
        profile.setImportedInsuranceSalary(SalaryAmounts.isPlausibleSalary(insuranceSalary) ? insuranceSalary : null);
        profile.setImportedProductSalary(SalaryAmounts.isPlausibleSalary(productSalary) ? productSalary : null);

        BigDecimal attraction = parseMoney(cellString(row, col, "lương thu hút"));
        if (attraction != null) {
            profile.setProfessionalAttractionSalary(attraction);
        }

        profileRepository.save(profile);

        LocalDate calcDate = seniorityAsOf != null ? seniorityAsOf : LocalDate.now();
        BigDecimal seniorityCalc = salaryCalculator.calculateSalarySeniority(
                salaryCalculator.calculateWorkingYears(emp.getHireDate(), calcDate),
                profile.getPriorRaiseYears(),
                profile.getDegreeConversionYears(),
                profile.getSalaryCategory() == SalaryCategory.DOCTOR);
        int gradeCalc = salaryCalculator.calculateGrade(seniorityCalc);
        String gradeExcel = cellString(row, col, "bậc");
        int gradeFromExcel = parseGradeFromLabel(gradeExcel);
        if (gradeFromExcel > 0 && gradeFromExcel != gradeCalc) {
            warnings.add(Map.of(
                    "row", rowNum,
                    "employee", emp.getFullName(),
                    "message",
                    "Bậc Excel (" + gradeFromExcel + ") khác bậc hệ thống (" + gradeCalc + ")"));
        }
    }

    private Optional<Employee> matchEmployee(Row row, Map<String, Integer> col) {
        String code = cellString(row, col, "mã nhân viên");
        if (code == null || code.isBlank()) {
            code = cellRaw(row, 0);
        }
        if (code != null && !code.isBlank()) {
            String trimmed = code.trim();
            Optional<Employee> byCode = employeeRepository.findByEmployeeCode(trimmed);
            if (byCode.isPresent()) {
                return byCode;
            }
            if (trimmed.matches("\\d{9,12}")) {
                Optional<Employee> byId = employeeRepository.findByIdCardNumber(trimmed);
                if (byId.isPresent()) {
                    return byId;
                }
            }
        }
        String name = cellString(row, col, "họ và tên");
        if (name == null || name.isBlank()) {
            return Optional.empty();
        }
        List<Employee> list = employeeRepository.findByFullNameIgnoreCaseTrim(name.trim());
        if (list.size() == 1) {
            return Optional.of(list.get(0));
        }
        if (list.size() > 1) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Trùng tên nhân viên: " + name.trim());
        }
        return Optional.empty();
    }

    public static BigDecimal parseMoney(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String s = raw.trim().replaceAll("\\s+", "");
        // Chỉ bỏ dấu chấm ngăn nghìn kiểu VN (4.930.000), tránh nhầm hệ số 1.3000000000000003
        if (s.matches("^(\\d{1,3})(\\.\\d{3})+$")) {
            s = s.replace(".", "");
        } else if (s.contains(",") && s.contains(".")) {
            s = s.replace(".", "").replace(",", ".");
        } else {
            s = s.replaceAll("[^\\d.,-]", "").replace(",", ".");
        }
        if (s.isBlank()) {
            return null;
        }
        try {
            return new BigDecimal(s);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public static BigDecimal parseDecimal(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return new BigDecimal(raw.replace(",", ".").trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public static int parseGradeFromLabel(String raw) {
        if (raw == null) {
            return 0;
        }
        Matcher m = GRADE_NUM.matcher(raw);
        if (m.find()) {
            return Integer.parseInt(m.group(1));
        }
        return 0;
    }

    public static EmployeeSalaryBlock parseBlock(String raw) {
        if (raw == null) {
            return null;
        }
        String u = raw.toUpperCase(Locale.ROOT);
        if (u.contains("GIÁN") || u.contains("GIAN")) {
            return EmployeeSalaryBlock.INDIRECT;
        }
        if (u.contains("TRỰC") || u.contains("TRUC")) {
            return EmployeeSalaryBlock.DIRECT;
        }
        return null;
    }

    private static BigDecimal[] parseTimeRange(String label) {
        if (label == null) {
            return new BigDecimal[] {BigDecimal.ZERO, null};
        }
        if (label.contains("10") && label.contains("trở")) {
            return new BigDecimal[] {BigDecimal.TEN, null};
        }
        Matcher m = Pattern.compile("(\\d+)\\s*-\\s*(\\d+)").matcher(label);
        if (m.find()) {
            return new BigDecimal[] {
                new BigDecimal(m.group(1)),
                new BigDecimal(m.group(2))
            };
        }
        return new BigDecimal[] {BigDecimal.ZERO, null};
    }

    private static BigDecimal[] findScaleAmountRow(Sheet sheet, int fromRow, String... labelParts) {
        for (int r = fromRow; r <= Math.min(fromRow + 8, sheet.getLastRowNum()); r++) {
            Row row = sheet.getRow(r);
            String label = row != null ? cellRaw(row, 2) : null;
            if (label == null) {
                continue;
            }
            String lower = label.toLowerCase(Locale.ROOT);
            for (String part : labelParts) {
                if (lower.contains(part.toLowerCase(Locale.ROOT))) {
                    return readGradeAmounts(row, 3, 10);
                }
            }
        }
        return null;
    }

    private static BigDecimal[] readGradeAmounts(Row row, int fromCol, int count) {
        BigDecimal[] arr = new BigDecimal[count];
        if (row == null) {
            return arr;
        }
        for (int i = 0; i < count; i++) {
            arr[i] = readNumericOrMoney(row, fromCol + i);
        }
        return arr;
    }

    private static BigDecimal readNumericOrMoney(Row row, int colIndex) {
        if (row == null) {
            return null;
        }
        Cell cell = row.getCell(colIndex);
        if (cell != null && cell.getCellType() == CellType.NUMERIC && !DateUtil.isCellDateFormatted(cell)) {
            return BigDecimal.valueOf(cell.getNumericCellValue());
        }
        return parseMoney(cellRaw(row, colIndex));
    }

    private static boolean rowCellContains(Row row, int colIndex, String text) {
        String v = cellRaw(row, colIndex);
        return v != null && v.toUpperCase(Locale.ROOT).contains(text.toUpperCase(Locale.ROOT));
    }

    private static boolean looksLikeSectionHeader(String name) {
        String u = name.toUpperCase(Locale.ROOT);
        return u.startsWith("KHOA ") || u.startsWith("PHÒNG ") || u.contains("THỐNG KÊ");
    }

    private static boolean isEmptyDataRow(Row row, Map<String, Integer> col) {
        String name = cellString(row, col, "họ và tên");
        return name == null || name.isBlank();
    }

    private static int findHeaderRow(Sheet sheet, String mustContain) {
        for (int r = 0; r <= Math.min(10, sheet.getLastRowNum()); r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                continue;
            }
            for (int c = 0; c < row.getLastCellNum(); c++) {
                String v = cellRaw(row, c);
                if (v != null && v.toLowerCase(Locale.ROOT).contains(mustContain)) {
                    return r;
                }
            }
        }
        return -1;
    }

    private static Map<String, Integer> buildHeaderMap(Row headerRow) {
        Map<String, Integer> col = new HashMap<>();
        for (int i = 0; i < headerRow.getLastCellNum(); i++) {
            Cell cell = headerRow.getCell(i);
            if (cell == null) {
                continue;
            }
            String h = FORMATTER.formatCellValue(cell).trim().toLowerCase(Locale.ROOT);
            if (!h.isEmpty()) {
                col.put(h, i);
            }
        }
        return col;
    }

    /** Dòng tiêu đề thâm niên nv.xlsx có 2 hàng: hàng chính + hàng Lương đóng BH / TỔNG LƯƠNG. */
    private static Map<String, Integer> buildSeniorityHeaderMap(Sheet sheet, int headerRow) {
        Map<String, Integer> col = new HashMap<>(buildHeaderMap(sheet.getRow(headerRow)));
        Row subRow = sheet.getRow(headerRow + 1);
        if (subRow != null) {
            for (int i = 0; i < subRow.getLastCellNum(); i++) {
                Cell cell = subRow.getCell(i);
                if (cell == null) {
                    continue;
                }
                String h = FORMATTER.formatCellValue(cell).trim().toLowerCase(Locale.ROOT);
                if (!h.isEmpty()) {
                    col.putIfAbsent(h, i);
                }
            }
        }
        return col;
    }

    /** Đọc lương từ file thâm niên: ưu tiên cột theo tiêu đề, fallback ngay sau cột Bậc. */
    private static BigDecimal readSeniorityMoney(Row row, Map<String, Integer> col, String... aliases) {
        int idx = resolveCol(col, aliases);
        if (idx >= 0) {
            BigDecimal v = cellMoneyAt(row, idx);
            if (v != null) {
                return v;
            }
        }
        int gradeCol = resolveCol(col, "bậc");
        if (gradeCol < 0) {
            return null;
        }
        int offset = 1;
        for (String alias : aliases) {
            if (alias.toLowerCase(Locale.ROOT).contains("đảm bảo")) {
                offset = 2;
                break;
            }
        }
        return cellMoneyAt(row, gradeCol + offset);
    }

    private static BigDecimal cellMoneyAt(Row row, int colIndex) {
        BigDecimal v = readNumericOrMoney(row, colIndex);
        if (v == null) {
            return null;
        }
        if (v.abs().compareTo(new BigDecimal("1000")) >= 0) {
            return v.setScale(0, RoundingMode.HALF_UP);
        }
        return null;
    }

    private static BigDecimal cellDecimal(Row row, Map<String, Integer> col, String... aliases) {
        int idx = resolveCol(col, aliases);
        if (idx < 0) {
            return null;
        }
        Cell cell = row.getCell(idx);
        if (cell != null && cell.getCellType() == CellType.NUMERIC && !DateUtil.isCellDateFormatted(cell)) {
            return BigDecimal.valueOf(cell.getNumericCellValue());
        }
        return parseDecimal(cellRaw(row, idx));
    }

    private static String cellString(Row row, Map<String, Integer> col, String... aliases) {
        int idx = resolveCol(col, aliases);
        if (idx < 0) {
            return null;
        }
        String v = cellRaw(row, idx);
        return v != null && !v.isBlank() ? v.trim() : null;
    }

    private static int resolveCol(Map<String, Integer> col, String... aliases) {
        for (String alias : aliases) {
            String key = alias.toLowerCase(Locale.ROOT).trim();
            if (col.containsKey(key)) {
                return col.get(key);
            }
        }
        for (String alias : aliases) {
            String sub = alias.toLowerCase(Locale.ROOT).trim();
            if (sub.length() < 5) {
                continue;
            }
            String bestKey = null;
            int bestIdx = -1;
            for (Map.Entry<String, Integer> e : col.entrySet()) {
                if (e.getKey().contains(sub) && (bestKey == null || e.getKey().length() > bestKey.length())) {
                    bestKey = e.getKey();
                    bestIdx = e.getValue();
                }
            }
            if (bestIdx >= 0) {
                return bestIdx;
            }
        }
        return -1;
    }

    private static BigDecimal sumDecimals(BigDecimal... values) {
        BigDecimal sum = BigDecimal.ZERO;
        for (BigDecimal v : values) {
            if (v != null) {
                sum = sum.add(v);
            }
        }
        return sum;
    }

    private static LocalDate extractSeniorityAsOfDate(Sheet sheet) {
        for (int r = 0; r <= Math.min(3, sheet.getLastRowNum()); r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                continue;
            }
            for (int c = 0; c < row.getLastCellNum(); c++) {
                Cell cell = row.getCell(c);
                if (cell != null && cell.getCellType() == CellType.NUMERIC && DateUtil.isCellDateFormatted(cell)) {
                    return cell.getDateCellValue().toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
                }
                String raw = cellRaw(row, c);
                if (raw == null) {
                    continue;
                }
                Matcher title = AS_OF_DATE.matcher(raw);
                if (title.find()) {
                    LocalDate parsed = parseDateString(title.group(1));
                    if (parsed != null) {
                        return parsed;
                    }
                }
            }
        }
        return null;
    }

    private static LocalDate parseDateString(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String trimmed = s.trim();
        if (trimmed.matches("\\d+(\\.\\d+)?")) {
            try {
                Date date = DateUtil.getJavaDate(Double.parseDouble(trimmed));
                return date.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
            } catch (Exception ignored) {
                return null;
            }
        }
        List<DateTimeFormatter> fmts = List.of(
                DateTimeFormatter.ofPattern("d/M/yyyy"),
                DateTimeFormatter.ofPattern("dd/MM/yyyy"),
                DateTimeFormatter.ISO_LOCAL_DATE);
        for (DateTimeFormatter f : fmts) {
            try {
                return LocalDate.parse(trimmed.substring(0, Math.min(trimmed.length(), 10)), f);
            } catch (DateTimeParseException ignored) {
            }
        }
        return null;
    }

    private static String cellRaw(Row row, int colIndex) {
        if (row == null) {
            return null;
        }
        Cell cell = row.getCell(colIndex);
        if (cell == null) {
            return null;
        }
        String v = FORMATTER.formatCellValue(cell).trim();
        return v.isEmpty() ? null : v;
    }

    private static LocalDate cellDate(Row row, Map<String, Integer> col, String... aliases) {
        int idx = resolveCol(col, aliases);
        if (idx < 0) {
            return null;
        }
        Cell cell = row.getCell(idx);
        if (cell != null && cell.getCellType() == CellType.NUMERIC && DateUtil.isCellDateFormatted(cell)) {
            return cell.getDateCellValue().toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
        }
        return parseDateString(cellRaw(row, idx));
    }

    private static void validateXlsx(MultipartFile file) {
        if (file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "File rỗng");
        }
        String fn = file.getOriginalFilename();
        if (fn == null || !fn.toLowerCase(Locale.ROOT).endsWith(".xlsx")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ hỗ trợ file .xlsx");
        }
    }
}
