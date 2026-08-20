package com.minhan.hrm.service;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.*;

/**
 * Import danh sách nhân viên trực kèm từ Excel.
 * NV trong danh sách chỉ được chọn ca TK cho đến khi duyệt đơn trực chính.
 * NV không có trong danh sách được chọn mọi loại trực bình thường.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AccompanyingDutyImportService {

    private static final DataFormatter FORMATTER = new DataFormatter(Locale.forLanguageTag("vi-VN"));

    private final EmployeeRepository employeeRepository;

    @Transactional
    public Map<String, Object> importAccompanyingDutyList(MultipartFile file) {
        if (file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "File rỗng");
        }
        String fn = file.getOriginalFilename();
        if (fn == null || !fn.toLowerCase(Locale.ROOT).endsWith(".xlsx")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ hỗ trợ file .xlsx");
        }

        Set<Long> listEmployeeIds = new LinkedHashSet<>();
        List<Map<String, Object>> errors = new ArrayList<>();
        int rowsRead = 0;
        List<String> sheetsProcessed = new ArrayList<>();

        try (InputStream in = file.getInputStream(); Workbook wb = new XSSFWorkbook(in)) {
            for (int si = 0; si < wb.getNumberOfSheets(); si++) {
                Sheet sheet = wb.getSheetAt(si);
                if (sheet == null || sheet.getPhysicalNumberOfRows() < 2) {
                    continue;
                }
                int headerRowIdx = findHeaderRow(sheet);
                if (headerRowIdx < 0) {
                    continue;
                }
                Map<String, Integer> col = buildHeaderMap(sheet.getRow(headerRowIdx));
                int cccdCol = resolveCol(col, "cccd", "mã cccd", "cmnd", "căn cước");
                int nameCol = resolveCol(col, "họ tên", "họ và tên", "ho ten", "hoten");
                if (cccdCol < 0 && nameCol < 0) {
                    continue;
                }

                String sheetLabel = sheet.getSheetName();
                sheetsProcessed.add(sheetLabel);
                int last = sheet.getLastRowNum();
                for (int r = headerRowIdx + 1; r <= last; r++) {
                    Row row = sheet.getRow(r);
                    if (row == null || isRowEmpty(row)) {
                        continue;
                    }
                    String cccd = cccdCol >= 0 ? cellText(sheet, row, cccdCol) : "";
                    String name = nameCol >= 0 ? cellText(sheet, row, nameCol) : "";
                    if (cccd.isBlank() && name.isBlank()) {
                        continue;
                    }
                    rowsRead++;
                    try {
                        Employee emp = resolveEmployee(cccd, name);
                        listEmployeeIds.add(emp.getId());
                    } catch (ApiException ex) {
                        errors.add(Map.of(
                                "sheet", sheetLabel,
                                "row", r + 1,
                                "message", ex.getMessage()));
                    }
                }
            }
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.error("Import DS trực kèm lỗi", e);
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đọc được file Excel: " + e.getMessage());
        }

        if (sheetsProcessed.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Không tìm thấy sheet có cột CCCD hoặc Họ tên trong file.");
        }
        if (listEmployeeIds.isEmpty()) {
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("rowsRead", rowsRead);
            result.put("listMatched", 0);
            result.put("tkOnlySet", 0);
            result.put("preservedAuthorized", 0);
            result.put("fullAccessSet", 0);
            result.put("errors", errors);
            result.put("sheetsProcessed", sheetsProcessed);
            if (errors.isEmpty()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "File không có dòng nhân viên hợp lệ.");
            }
            return result;
        }

        // NV trong file Excel → chỉ trực kèm (TK). Ghi đè cả trường hợp đã từng được trực chính.
        int tkOnlySet = 0;
        for (Long empId : listEmployeeIds) {
            Employee emp = employeeRepository.findById(empId).orElseThrow();
            emp.setMainDutyAuthorized(false);
            employeeRepository.save(emp);
            tkOnlySet++;
        }

        // NV không có trong danh sách → mở đầy đủ loại trực.
        int fullAccessSet = 0;
        for (Employee emp : employeeRepository.findByStatusNot(EmployeeStatus.TERMINATED)) {
            if (listEmployeeIds.contains(emp.getId())) {
                continue;
            }
            if (!emp.isMainDutyAuthorized()) {
                emp.setMainDutyAuthorized(true);
                employeeRepository.save(emp);
                fullAccessSet++;
            }
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("rowsRead", rowsRead);
        result.put("listMatched", listEmployeeIds.size());
        result.put("tkOnlySet", tkOnlySet);
        result.put("preservedAuthorized", 0);
        result.put("fullAccessSet", fullAccessSet);
        result.put("errors", errors);
        result.put("sheetsProcessed", sheetsProcessed);
        return result;
    }

    private Employee resolveEmployee(String cccdRaw, String nameRaw) {
        String cccd = normalizeIdCard(cccdRaw);
        if (!cccd.isBlank()) {
            Optional<Employee> byCccd = employeeRepository.findByIdCardNumberNormalized(cccd);
            if (byCccd.isEmpty()) {
                byCccd = employeeRepository.findByIdCardNumber(cccd);
            }
            if (byCccd.isPresent()) {
                return byCccd.get();
            }
        }
        String name = nameRaw != null ? nameRaw.trim() : "";
        if (!name.isBlank()) {
            List<Employee> matches = employeeRepository.findByFullNameIgnoreCaseTrim(name).stream()
                    .filter(e -> e.getStatus() != EmployeeStatus.TERMINATED)
                    .toList();
            if (matches.size() == 1) {
                return matches.get(0);
            }
            if (matches.size() > 1) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Trùng tên «" + name + "» — cần CCCD để xác định");
            }
        }
        String hint = !cccd.isBlank() ? "CCCD " + cccd : "«" + name + "»";
        throw new ApiException(HttpStatus.BAD_REQUEST, "Không tìm thấy nhân viên: " + hint);
    }

    private static String normalizeIdCard(String raw) {
        if (raw == null) {
            return "";
        }
        // Chỉ giữ chữ số — CCCD Excel thường có khoảng trắng / dấu chấm.
        return raw.replaceAll("\\D+", "").trim();
    }

    private static int findHeaderRow(Sheet sheet) {
        int max = Math.min(sheet.getLastRowNum(), 30);
        for (int r = 0; r <= max; r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                continue;
            }
            Map<String, Integer> col = buildHeaderMap(row);
            boolean hasCccd = resolveCol(col, "cccd", "mã cccd", "cmnd", "căn cước") >= 0;
            boolean hasName = resolveCol(col, "họ tên", "họ và tên", "ho ten", "hoten") >= 0;
            if (hasCccd || hasName) {
                return r;
            }
        }
        return -1;
    }

    private static Map<String, Integer> buildHeaderMap(Row headerRow) {
        Map<String, Integer> map = new LinkedHashMap<>();
        if (headerRow == null) {
            return map;
        }
        short last = headerRow.getLastCellNum();
        for (int c = 0; c < last; c++) {
            Cell cell = headerRow.getCell(c);
            String raw = cell == null ? "" : FORMATTER.formatCellValue(cell).trim();
            if (raw.isEmpty()) {
                continue;
            }
            map.put(normalizeHeader(raw), c);
        }
        return map;
    }

    private static String normalizeHeader(String s) {
        return s.toLowerCase(Locale.forLanguageTag("vi-VN"))
                .replace('\u00A0', ' ')
                .replaceAll("\\s+", " ")
                .trim();
    }

    private static int resolveCol(Map<String, Integer> col, String... aliases) {
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

    private static String cellText(Sheet sheet, Row row, int col) {
        Cell cell = getEffectiveCell(sheet, row.getRowNum(), col);
        if (cell == null) {
            return "";
        }
        return FORMATTER.formatCellValue(cell).trim();
    }

    private static Cell getEffectiveCell(Sheet sheet, int rowIndex, int columnIndex) {
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
        return row == null ? null : row.getCell(columnIndex);
    }

    private static boolean isRowEmpty(Row row) {
        short last = row.getLastCellNum();
        for (int c = 0; c < last; c++) {
            Cell cell = row.getCell(c);
            if (cell != null && cell.getCellType() != CellType.BLANK) {
                String v = FORMATTER.formatCellValue(cell).trim();
                if (!v.isEmpty()) {
                    return false;
                }
            }
        }
        return true;
    }
}
