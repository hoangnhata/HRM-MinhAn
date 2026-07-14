package com.minhan.hrm.service;

import com.minhan.hrm.account.EmployeeAccountProvisioner;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.*;
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

    private static final DataFormatter FORMATTER = new DataFormatter(Locale.forLanguageTag("vi-VN"));

    @Transactional
    public Map<String, Object> importWorkforceExcel(MultipartFile file) {
        if (file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "File rỗng");
        }
        String fn = file.getOriginalFilename();
        if (fn == null || (!fn.toLowerCase(Locale.ROOT).endsWith(".xlsx"))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ hỗ trợ file .xlsx (TỔNG HỢP THÔNG TIN NHÂN LỰC BVMA)");
        }

        final int[] created = {0};
        final int[] updated = {0};
        List<Map<String, Object>> errors = new ArrayList<>();
        List<String> sheetsProcessed = new ArrayList<>();

        try (InputStream in = file.getInputStream(); Workbook wb = new XSSFWorkbook(in)) {
            // Chỉ xử lý ĐÚNG 2 sheet theo tên (đã bỏ dấu) để tránh nhận nhầm các sheet phụ
            // như "Trang tính8", "Đề nghị trực chính", "HĐTK", "NV ứng tuyển"...
            Sheet officialSheet = null;
            Sheet trialSheet = null;

            for (int si = 0; si < wb.getNumberOfSheets(); si++) {
                Sheet sheet = wb.getSheetAt(si);
                if (sheet == null || sheet.getPhysicalNumberOfRows() < 2) {
                    continue;
                }
                String name = stripAccents(sheet.getSheetName());
                if (trialSheet == null && (name.contains("thu viec") || name.contains("thuc tap"))) {
                    trialSheet = sheet;
                } else if (officialSheet == null && name.contains("chinh thuc")) {
                    officialSheet = sheet;
                }
            }

            if (officialSheet != null) {
                String label = officialSheet.getSheetName();
                importOfficialSheet(officialSheet, label, errors, () -> created[0]++, () -> updated[0]++);
                sheetsProcessed.add(label + " (chính thức)");
            }
            if (trialSheet != null) {
                String label = trialSheet.getSheetName();
                importTrialSheet(trialSheet, label, errors, () -> created[0]++, () -> updated[0]++);
                sheetsProcessed.add(label + " (thử việc/thực tập)");
            }

            if (officialSheet == null && trialSheet == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Không tìm thấy sheet \"Danh sách NV chính thức\" hoặc \"Thử việcThực tập\" trong file.");
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
                boolean wasUpdate = upsertOfficialRow(sheet, r, col, code, fullName.trim());
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

    private void importTrialSheet(
            Sheet sheet,
            String sheetLabel,
            List<Map<String, Object>> errors,
            Runnable onCreated,
            Runnable onUpdated) {
        int headerRowIdx = findHeaderRow(sheet, "họ tên", "khoa");
        if (headerRowIdx < 0) {
            headerRowIdx = findHeaderRow(sheet, "họ tên", "từ ngày");
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
        boolean hasPosition = cellString(sheet, rowIndex, col, "vị trí làm việc", "vị trí") != null;
        int filled = (hasDept ? 1 : 0) + (hasPhone ? 1 : 0) + (hasDob ? 1 : 0)
                + (hasEmail ? 1 : 0) + (hasGender ? 1 : 0) + (hasPosition ? 1 : 0);
        return filled < 2;
    }

    private static Map<String, Object> rowError(String sheet, int rowIndex, String message) {
        return Map.of("row", rowIndex + 1, "sheet", sheet, "message", message);
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

    private boolean upsertOfficialRow(Sheet sheet, int rowIndex, Map<String, Integer> col, String employeeCode, String fullName) {
        LocalDate probation = cellDate(sheet, rowIndex, col, "ngày thử việc");
        LocalDate official = cellDate(sheet, rowIndex, col, "ngày chính thức");
        // Sheet "Danh sách NV chính thức" — luôn là nhân viên chính thức; ngày thử việc chỉ lưu lịch sử.
        return upsertRow(sheet, rowIndex, col, employeeCode, fullName, EmployeeStatus.ACTIVE, probation, official);
    }

    private boolean upsertTrialRow(Sheet sheet, int rowIndex, Map<String, Integer> col, String fullName) {
        LocalDate dob = cellDate(sheet, rowIndex, col, "ngày sinh");
        LocalDate fromDate = cellDate(sheet, rowIndex, col, "từ ngày", "tu ngay");
        String position = cellString(sheet, rowIndex, col, "vị trí", "vi tri");
        String degree = cellString(sheet, rowIndex, col, "bằng cấp", "bang cap");
        String note = cellString(sheet, rowIndex, col, "ghi chú", "ghi chu");
        String salaryNote = cellString(sheet, rowIndex, col, "mức lương", "muc luong");
        EmployeeStatus status = inferTrialStatus(position, note);

        Department dept = findOrCreateDepartment(cellString(sheet, rowIndex, col,
                "khoa/phòng", "khoa/ phòng", "khoa phòng", "khoa", "đơn vị công tác"));
        Position pos = findOrCreatePosition(position);

        Optional<Employee> trialExisting = findTrialOnlyEmployee(fullName, dob, fromDate);
        Optional<Employee> officialExisting = findOfficialByNameAndDob(fullName, dob);

        if (officialExisting.isPresent()) {
            Employee emp = officialExisting.get();
            applyTrialStatus(emp, status, fromDate, dept, pos);
            saveTrialWorkforceDetails(sheet, rowIndex, col, emp, fromDate, note, salaryNote, degree);
            employeeRepository.save(emp);
            return true;
        }

        if (trialExisting.isPresent()) {
            Employee emp = trialExisting.get();
            UserAccount user = emp.getUser();
            emp.setFullName(fullName);
            if (dob != null) {
                emp.setDateOfBirth(dob);
            }
            emp.setDepartment(dept);
            emp.setPosition(pos);
            if (fromDate != null) {
                emp.setHireDate(fromDate);
            }
            if (emp.getStatus() != EmployeeStatus.TERMINATED) {
                emp.setStatus(status);
            }
            employeeRepository.save(emp);
            userAccountRepository.save(user);
            saveTrialWorkforceDetails(sheet, rowIndex, col, emp, fromDate, note, salaryNote, degree);
            return true;
        }

        String employeeCode = generateTrialCode(fullName, dob, fromDate);
        LocalDate hire = fromDate != null ? fromDate : LocalDate.now();
        String email = ensureUniqueEmail("tv_" + sanitizeUsername(employeeCode) + "@import.minhan.vn", employeeCode);

        UserAccount user = employeeAccountProvisioner.buildNewEmployeeUser(null, employeeCode, email);
        user = userAccountRepository.save(user);

        Employee emp = Employee.builder()
                .user(user)
                .employeeCode(employeeCode)
                .fullName(fullName)
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

        saveTrialWorkforceDetails(sheet, rowIndex, col, emp, fromDate, note, salaryNote, degree);
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
            String degree) {
        EmployeeWorkforceDetails d = workforceDetailsRepository.findByEmployee(emp).orElse(
                EmployeeWorkforceDetails.builder().employee(emp).build());
        String degreeFromSheet = trimToNull(cellString(sheet, rowIndex, col, "bằng cấp", "bang cap"));
        d.setDegree(degreeFromSheet != null ? degreeFromSheet : trimToNull(degree));
        d.setProbationStartDate(fromDate);
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
        String s = raw.trim();
        if (s.matches("\\d+\\.0+")) {
            s = s.substring(0, s.indexOf('.'));
        }
        return s;
    }

    private static EmployeeStatus inferTrialStatus(String position, String note) {
        String combined = ((position != null ? position : "") + " " + (note != null ? note : "")).toLowerCase(Locale.ROOT);
        if (combined.contains("thực tập") || combined.contains("thuc tap") || combined.contains("intern")) {
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
            LocalDate probationOverride,
            LocalDate officialOverride) {
        Department dept = findOrCreateDepartment(cellString(sheet, rowIndex, col, "đơn vị công tác"));
        Position pos = findOrCreatePosition(cellString(sheet, rowIndex, col, "vị trí làm việc"));

        LocalDate dob = cellDate(sheet, rowIndex, col, "ngày sinh");
        String phone = cellString(sheet, rowIndex, col, "đt di động");
        String address = cellString(sheet, rowIndex, col, "địa chỉ");
        String cccd = firstNonNullStr(
                cellString(sheet, rowIndex, col, "mã cccd", "cccd"),
                cellString(sheet, rowIndex, col, "mã cmnd"));
        LocalDate cccdIssue = cellDate(sheet, rowIndex, col, "ngày cấp");
        String emailRaw = cellString(sheet, rowIndex, col, "email");
        String email = (emailRaw == null || emailRaw.isBlank())
                ? ("nv_" + sanitizeUsername(employeeCode) + "@import.minhan.vn")
                : emailRaw.trim();
        email = ensureUniqueEmail(email, employeeCode);

        LocalDate hire = firstNonNull(
                cellDate(sheet, rowIndex, col, "ngày chính thức"),
                cellDate(sheet, rowIndex, col, "ngày thử việc"),
                LocalDate.now());

        Optional<Employee> existing = employeeRepository.findByEmployeeCode(employeeCode);
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
            if (emp.getStatus() != EmployeeStatus.TERMINATED) {
                emp.setStatus(targetStatus);
            }
            employeeRepository.save(emp);
            userAccountRepository.save(user);
            saveWorkforceDetails(sheet, rowIndex, col, emp);
            saveContractIfAny(sheet, rowIndex, col, emp);
            saveSalaryProfileIfAny(sheet, rowIndex, col, emp);
            return true;
        }

        user = employeeAccountProvisioner.buildNewEmployeeUser(phone, employeeCode, email);
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
        String catRaw = cellString(sheet, rowIndex, col,
                "đối tượng lương", "loại lương", "nhóm lương", "đối tượng tính lương");
        String blockRaw = cellString(sheet, rowIndex, col, "khối lương", "khối", "khối làm việc");
        String qualRaw = cellString(sheet, rowIndex, col, "trình độ", "trình độ đào tạo");
        String doctorCode = cellString(sheet, rowIndex, col, "mã trình độ bs", "mã bác sỹ", "trình độ bs");
        BigDecimal priorRaise = cellDecimal(sheet, rowIndex, col,
                "thời hạn nâng lương trước", "thâm niên nâng lương trước", "nâng lương trước");
        BigDecimal degreeConv = cellDecimal(sheet, rowIndex, col, "chuyển đổi bằng cấp", "thời gian chuyển đổi bằng cấp");
        BigDecimal attraction = cellDecimal(sheet, rowIndex, col,
                "lương thu hút", "lương thu hút đánh giá cm", "lương thu hút, đánh giá cm");
        String qualNote = cellString(sheet, rowIndex, col, "ghi chú trình độ", "trình độ / ghi chú");

        if ((catRaw == null || catRaw.isBlank())
                && (blockRaw == null || blockRaw.isBlank())
                && (qualRaw == null || qualRaw.isBlank())
                && doctorCode == null
                && priorRaise == null
                && degreeConv == null
                && attraction == null) {
            return;
        }

        EmployeeSalaryProfile profile = salaryProfileRepository.findByEmployee(emp).orElse(null);
        SalaryCategory category = parseSalaryCategory(catRaw);
        if (category == null && doctorCode != null && !doctorCode.isBlank()) {
            category = SalaryCategory.DOCTOR;
        }
        if (profile == null && category == null) {
            return;
        }
        if (profile == null) {
            profile = EmployeeSalaryProfile.builder().employee(emp).salaryCategory(category).build();
        } else if (category != null) {
            profile.setSalaryCategory(category);
        } else {
            category = profile.getSalaryCategory();
        }
        profile.setSalaryCategory(category);
        if (category == SalaryCategory.EMPLOYEE) {
            profile.setEmployeeBlock(parseEmployeeBlock(blockRaw));
            if (qualRaw != null && !qualRaw.isBlank()) {
                profile.setQualification(SalaryQualifications.normalizeQualification(qualRaw));
                profile.setTierGroup(SalaryQualifications.tierGroupFromQualification(profile.getQualification()));
            }
            profile.setDoctorQualificationCode(null);
        } else {
            profile.setEmployeeBlock(null);
            profile.setDoctorQualificationCode(trimToNull(doctorCode));
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
        salaryProfileRepository.save(profile);
    }

    private static SalaryCategory parseSalaryCategory(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String t = raw.trim().toLowerCase(Locale.ROOT);
        if (t.contains("bác") || t.contains("bac") || t.contains("bs") || t.contains("doctor")) {
            return SalaryCategory.DOCTOR;
        }
        if (t.contains("nhân viên") || t.contains("nhan vien") || t.contains("employee")) {
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
        String s = cellString(sheet, rowIndex, col, keys);
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
        d.setWorkUnitDetail(trimToNull(cellString(sheet, rowIndex, col, "bộ phận")));
        d.setInsuranceParticipation(trimToNull(cellString(sheet, rowIndex, col, "tham gia bảo hiểm")));
        d.setWorkforceNotes(trimToNull(cellString(sheet, rowIndex, col, "ghi chú")));
        d.setProbationStartDate(cellDate(sheet, rowIndex, col, "ngày thử việc"));
        d.setOfficialStartDate(cellDate(sheet, rowIndex, col, "ngày chính thức"));
        d.setContractNumber(trimToNull(cellString(sheet, rowIndex, col, "số hợp đồng")));
        d.setContractSignDate(cellDate(sheet, rowIndex, col, "ngày ký hđ"));
        d.setContractTerm(trimToNull(cellString(sheet, rowIndex, col, "thời hạn hợp đồng")));
        d.setSocialInsuranceBook(trimToNull(cellString(sheet, rowIndex, col, "số sổ bh")));
        d.setAttendanceCode(trimToNull(cellString(sheet, rowIndex, col, "mã chấm công")));
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
        String name = unitName.trim();
        return departmentRepository.findByNameIgnoreCase(name).orElseGet(() -> {
            String code = buildUniqueDeptCode(name);
            return departmentRepository.save(Department.builder().code(code).name(name).build());
        });
    }

    private Position findOrCreatePosition(String title) {
        if (title == null || title.isBlank()) {
            return positionRepository.findByCode("NV").orElseGet(() ->
                    positionRepository.save(Position.builder().code("NV").title("Nhân viên").levelRank(1).build()));
        }
        String t = title.trim();
        return positionRepository.findByTitleIgnoreCase(t).orElseGet(() -> {
            String code = buildUniquePosCode(t);
            return positionRepository.save(Position.builder().code(code).title(t).levelRank(2).build());
        });
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
        return s.toLowerCase(Locale.forLanguageTag("vi-VN"))
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
        String v = FORMATTER.formatCellValue(cell).trim();
        return v.isEmpty() ? null : v;
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
        if (cell.getCellType() == CellType.NUMERIC && DateUtil.isCellDateFormatted(cell)) {
            return cell.getDateCellValue().toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
        }
        String s = FORMATTER.formatCellValue(cell).trim();
        if (s.isEmpty()) {
            return null;
        }
        List<DateTimeFormatter> fmts = List.of(
                DateTimeFormatter.ofPattern("d/M/yyyy"),
                DateTimeFormatter.ofPattern("dd/MM/yyyy"),
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
}
