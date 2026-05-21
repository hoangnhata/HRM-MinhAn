package com.minhan.hrm.service;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
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

    private final HrmProperties hrmProperties;
    private final DepartmentRepository departmentRepository;
    private final PositionRepository positionRepository;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeRepository employeeRepository;
    private final SalaryInfoRepository salaryInfoRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;
    private final ContractRepository contractRepository;
    private final PasswordEncoder passwordEncoder;

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

        int created = 0;
        int updated = 0;
        List<Map<String, Object>> errors = new ArrayList<>();

        try (InputStream in = file.getInputStream(); Workbook wb = new XSSFWorkbook(in)) {
            Sheet sheet = wb.getSheetAt(0);
            if (sheet.getPhysicalNumberOfRows() < 2) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Sheet không có dữ liệu");
            }
            Row headerRow = sheet.getRow(0);
            if (headerRow == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu dòng tiêu đề");
            }
            Map<String, Integer> col = buildHeaderMap(headerRow);

            int last = sheet.getLastRowNum();
            for (int r = 1; r <= last; r++) {
                Row row = sheet.getRow(r);
                if (row == null) {
                    continue;
                }
                try {
                    String code = cellString(sheet, r, col, "mã nhân viên");
                    if (code == null || code.isBlank()) {
                        continue;
                    }
                    code = code.trim();
                    String fullName = cellString(sheet, r, col, "họ và tên");
                    if (fullName == null || fullName.isBlank()) {
                        errors.add(Map.of("row", r + 1, "message", "Thiếu họ tên"));
                        continue;
                    }
                    boolean wasUpdate = upsertRow(sheet, r, col, code, fullName.trim());
                    if (wasUpdate) {
                        updated++;
                    } else {
                        created++;
                    }
                } catch (Exception ex) {
                    log.warn("Import row {}: {}", r + 1, ex.getMessage());
                    errors.add(Map.of("row", r + 1, "message", ex.getMessage() != null ? ex.getMessage() : "Lỗi không xác định"));
                }
            }
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.error("Import Excel lỗi", e);
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đọc được file Excel: " + e.getMessage());
        }

        return Map.of(
                "created", created,
                "updated", updated,
                "errors", errors);
    }

    private boolean upsertRow(Sheet sheet, int rowIndex, Map<String, Integer> col, String employeeCode, String fullName) {
        Department dept = findOrCreateDepartment(cellString(sheet, rowIndex, col, "đơn vị công tác"));
        Position pos = findOrCreatePosition(cellString(sheet, rowIndex, col, "vị trí làm việc"));

        LocalDate dob = cellDate(sheet, rowIndex, col, "ngày sinh");
        String phone = cellString(sheet, rowIndex, col, "đt di động");
        String address = cellString(sheet, rowIndex, col, "địa chỉ");
        String cccd = cellString(sheet, rowIndex, col, "mã cccd");
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
            emp.setPhone(trimToNull(phone));
            emp.setIdCardNumber(trimToNull(cccd));
            emp.setDateOfBirth(dob);
            emp.setAddress(trimToNull(address));
            emp.setGender(trimToNull(cellString(sheet, rowIndex, col, "giới tính")));
            emp.setDepartment(dept);
            emp.setPosition(pos);
            emp.setHireDate(hire);
            employeeRepository.save(emp);
            userAccountRepository.save(user);
            saveWorkforceDetails(sheet, rowIndex, col, emp);
            saveContractIfAny(sheet, rowIndex, col, emp);
            return true;
        }

        String usernameBase = sanitizeUsername(employeeCode);
        String username = uniqueUsername(usernameBase);

        user = UserAccount.builder()
                .username(username)
                .passwordHash(passwordEncoder.encode(hrmProperties.getImportConfig().getDefaultEmployeePassword()))
                .email(email)
                .role(UserRole.EMPLOYEE)
                .enabled(true)
                .build();
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
                .status(EmployeeStatus.ACTIVE)
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
        return false;
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

    private String uniqueUsername(String base) {
        String u = base;
        int i = 0;
        while (userAccountRepository.existsByUsername(u)) {
            u = base + (++i);
        }
        return u;
    }

    private static String sanitizeUsername(String code) {
        String s = code.replaceAll("[^a-zA-Z0-9]", "");
        if (s.isEmpty()) {
            s = "nv" + Math.abs(code.hashCode() % 1_000_000);
        }
        if (s.length() > 50) {
            s = s.substring(0, 50);
        }
        return s.toLowerCase(Locale.ROOT);
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
