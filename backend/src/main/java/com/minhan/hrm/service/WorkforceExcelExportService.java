package com.minhan.hrm.service;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.CreationHelper;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.VerticalAlignment;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFColor;
import org.apache.poi.xssf.usermodel.XSSFFont;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.time.LocalDate;
import java.time.Period;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Xuất Excel nhân lực theo đúng cấu trúc file nhập
 * (sheet «Danh sách NV chính thức» + «Thử việcThực tập»), dữ liệu chuẩn từ DB.
 */
@Service
@RequiredArgsConstructor
public class WorkforceExcelExportService {

    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");

    private static final String[] OFFICIAL_HEADERS = {
            "STT",
            "Mã nhân viên",
            "Họ và tên",
            "Họ tên trên bảng lương",
            "Giới tính",
            "Ngày sinh",
            "Kiểm tra trùng",
            "ĐT di động",
            "ĐỊA CHỈ",
            "MÃ CCCD",
            "Ngày cấp",
            "EMAIL",
            "Vị trí làm việc",
            "CHUYÊN NGÀNH/ CHUYÊN MÔN",
            "BẰNG CẤP",
            "STK ĐĂNG KÝ NHẬN LƯƠNG",
            "NGÂN HÀNG ĐĂNG KÝ NHẬN LƯƠNG",
            "Đơn vị công tác",
            "Bộ phận",
            "Tham gia bảo hiểm",
            "Ghi chú",
            "Ngày thử việc",
            "Ngày chính thức",
            "SỐ HỢP ĐỒNG",
            "NGÀY KÝ HĐ",
            "THỜI HẠN HỢP ĐỒNG",
            "Thời gian chính thức",
            "Thâm niên",
            "Số sổ bh",
            "Mã chấm công",
            "SỐ CCHN",
            "NGÀY CẤP CCHN",
            "Văn bằng chuyên môn",
            "Phạm vi hành nghề",
            "CHỨNG CHỈ ĐÀO TẠO KHÁC",
            "CKI",
            "THÔNG TIN NGƯỜI PHỤ THUỘC"
    };

    private static final String[] TRIAL_HEADERS = {
            "STT",
            "Họ tên",
            "Ngày sinh",
            "Vị trí",
            "Bằng cấp",
            "Khoa/Phòng",
            "Mức lương",
            "Từ ngày",
            "Ghi chú"
    };

    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;

    @Transactional(readOnly = true)
    public byte[] exportWorkforceExcel() {
        List<Employee> all = employeeRepository.findAll(Sort.by(Sort.Direction.ASC, "fullName"));
        Map<Long, EmployeeWorkforceDetails> detailsById = all.isEmpty()
                ? Map.of()
                : workforceDetailsRepository.findByEmployeeIn(all).stream()
                        .collect(Collectors.toMap(EmployeeWorkforceDetails::getEmployeeId, d -> d, (a, b) -> a));

        List<Employee> official = new ArrayList<>();
        List<Employee> trial = new ArrayList<>();
        for (Employee e : all) {
            if (e.getStatus() == EmployeeStatus.TERMINATED) {
                continue;
            }
            if (isTrialRecord(e)) {
                trial.add(e);
            } else {
                official.add(e);
            }
        }
        official.sort(Comparator.comparing(Employee::getFullName, String.CASE_INSENSITIVE_ORDER));
        trial.sort(Comparator.comparing(Employee::getFullName, String.CASE_INSENSITIVE_ORDER));

        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Styles styles = new Styles(wb);
            writeOfficialSheet(wb, styles, official, detailsById);
            writeTrialSheet(wb, styles, trial, detailsById);
            wb.write(out);
            return out.toByteArray();
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file Excel: " + ex.getMessage());
        }
    }

    private void writeOfficialSheet(
            Workbook wb,
            Styles styles,
            List<Employee> employees,
            Map<Long, EmployeeWorkforceDetails> detailsById) {
        Sheet sheet = wb.createSheet("Danh sách NV chính thức");
        Row title = sheet.createRow(0);
        Cell titleCell = title.createCell(0);
        titleCell.setCellValue("DANH SÁCH NHÂN VIÊN CHÍNH THỨC — BỆNH VIỆN MINH AN (xuất từ hệ thống HRM)");
        titleCell.setCellStyle(styles.title);
        sheet.addMergedRegion(new CellRangeAddress(0, 0, 0, OFFICIAL_HEADERS.length - 1));

        Row header = sheet.createRow(1);
        for (int i = 0; i < OFFICIAL_HEADERS.length; i++) {
            Cell cell = header.createCell(i);
            cell.setCellValue(OFFICIAL_HEADERS[i]);
            cell.setCellStyle(styles.header);
        }

        int r = 2;
        int stt = 1;
        for (Employee emp : employees) {
            EmployeeWorkforceDetails w = detailsById.get(emp.getId());
            Row row = sheet.createRow(r++);
            int c = 0;
            setNumber(row, c++, stt++, styles.center);
            setText(row, c++, emp.getEmployeeCode(), styles.text);
            setText(row, c++, emp.getFullName(), styles.text);
            setText(row, c++, firstNonBlank(w != null ? w.getPayrollDisplayName() : null, emp.getFullName()), styles.text);
            setText(row, c++, emp.getGender(), styles.center);
            setDate(row, c++, emp.getDateOfBirth(), styles.date);
            setText(row, c++, "", styles.center);
            setText(row, c++, emp.getPhone(), styles.text);
            setText(row, c++, emp.getAddress(), styles.wrap);
            setText(row, c++, emp.getIdCardNumber(), styles.text);
            setDate(row, c++, w != null ? w.getIdCardIssueDate() : null, styles.date);
            setText(row, c++, emp.getUser() != null ? emp.getUser().getEmail() : null, styles.text);
            setText(row, c++, emp.getPosition() != null ? emp.getPosition().getTitle() : null, styles.text);
            setText(row, c++, w != null ? w.getSpecialty() : null, styles.wrap);
            setText(row, c++, w != null ? w.getDegree() : null, styles.text);
            setText(row, c++, w != null ? w.getBankAccount() : null, styles.text);
            setText(row, c++, w != null ? w.getBankName() : null, styles.text);
            setText(row, c++, emp.getDepartment() != null ? emp.getDepartment().getName() : null, styles.text);
            setText(row, c++, w != null ? w.getWorkUnitDetail() : null, styles.text);
            setText(row, c++, w != null ? w.getInsuranceParticipation() : null, styles.text);
            setText(row, c++, notesWithoutSalary(w != null ? w.getWorkforceNotes() : null), styles.wrap);
            setDate(row, c++, w != null ? w.getProbationStartDate() : null, styles.date);
            LocalDate official = w != null && w.getOfficialStartDate() != null
                    ? w.getOfficialStartDate()
                    : emp.getHireDate();
            setDate(row, c++, official, styles.date);
            setText(row, c++, w != null ? w.getContractNumber() : null, styles.text);
            setDate(row, c++, w != null ? w.getContractSignDate() : null, styles.date);
            setText(row, c++, w != null ? w.getContractTerm() : null, styles.wrap);
            setText(row, c++, formatDurationVi(official), styles.text);
            String tenure = w != null && w.getTenureText() != null && !w.getTenureText().isBlank()
                    ? w.getTenureText()
                    : formatDurationVi(emp.getHireDate());
            setText(row, c++, tenure, styles.text);
            setText(row, c++, w != null ? w.getSocialInsuranceBook() : null, styles.text);
            setText(row, c++, w != null ? w.getAttendanceCode() : null, styles.text);
            setText(row, c++, w != null ? w.getPracticeCertNumber() : null, styles.text);
            setText(row, c++, w != null ? w.getPracticeCertDateRaw() : null, styles.text);
            setText(row, c++, w != null ? w.getProfessionalDiploma() : null, styles.wrap);
            setText(row, c++, w != null ? w.getPracticeScope() : null, styles.wrap);
            setText(row, c++, w != null ? w.getOtherTrainingCertificates() : null, styles.wrap);
            setText(row, c++, w != null ? w.getCki() : null, styles.wrap);
            setText(row, c++, w != null ? w.getDependentsInfo() : null, styles.wrap);
        }

        autosize(sheet, OFFICIAL_HEADERS.length);
        sheet.createFreezePane(3, 2);
    }

    private void writeTrialSheet(
            Workbook wb,
            Styles styles,
            List<Employee> employees,
            Map<Long, EmployeeWorkforceDetails> detailsById) {
        Sheet sheet = wb.createSheet("Thử việcThực tập");
        Row title = sheet.createRow(0);
        Cell titleCell = title.createCell(0);
        titleCell.setCellValue("DANH SÁCH NHÂN VIÊN THỬ VIỆC/ THỰC TẬP/ TRẢI NGHIỆM (xuất từ hệ thống HRM)");
        titleCell.setCellStyle(styles.title);
        sheet.addMergedRegion(new CellRangeAddress(0, 0, 0, TRIAL_HEADERS.length - 1));

        // Giữ khoảng trống giống file mẫu (tiêu đề cột ở dòng 3)
        sheet.createRow(1);
        Row header = sheet.createRow(2);
        for (int i = 0; i < TRIAL_HEADERS.length; i++) {
            Cell cell = header.createCell(i);
            cell.setCellValue(TRIAL_HEADERS[i]);
            cell.setCellStyle(styles.header);
        }

        int r = 3;
        int stt = 1;
        for (Employee emp : employees) {
            EmployeeWorkforceDetails w = detailsById.get(emp.getId());
            Row row = sheet.createRow(r++);
            int c = 0;
            setNumber(row, c++, stt++, styles.center);
            setText(row, c++, emp.getFullName(), styles.text);
            setDate(row, c++, emp.getDateOfBirth(), styles.date);
            setText(row, c++, emp.getPosition() != null ? emp.getPosition().getTitle() : null, styles.text);
            setText(row, c++, w != null ? w.getDegree() : null, styles.text);
            setText(row, c++, emp.getDepartment() != null ? emp.getDepartment().getName() : null, styles.text);
            setText(row, c++, extractSalaryNote(w != null ? w.getWorkforceNotes() : null), styles.text);
            LocalDate from = w != null && w.getProbationStartDate() != null
                    ? w.getProbationStartDate()
                    : emp.getHireDate();
            setDate(row, c++, from, styles.date);
            setText(row, c++, notesWithoutSalary(w != null ? w.getWorkforceNotes() : null), styles.wrap);
        }

        autosize(sheet, TRIAL_HEADERS.length);
        sheet.createFreezePane(2, 3);
    }

    private static boolean isTrialRecord(Employee e) {
        if (e.getStatus() == EmployeeStatus.PROBATION || e.getStatus() == EmployeeStatus.INTERN) {
            return true;
        }
        String code = e.getEmployeeCode();
        return code != null && code.toUpperCase(Locale.ROOT).startsWith("TV-");
    }

    private static String formatDurationVi(LocalDate from) {
        if (from == null) {
            return "";
        }
        Period p = Period.between(from, LocalDate.now(VN));
        if (p.isNegative()) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        if (p.getYears() > 0) {
            sb.append(p.getYears()).append(" năm");
        }
        if (p.getMonths() > 0) {
            if (sb.length() > 0) {
                sb.append(' ');
            }
            sb.append(p.getMonths()).append(" tháng");
        }
        if (sb.length() == 0) {
            if (p.getDays() > 0) {
                sb.append(p.getDays()).append(" ngày");
            } else {
                sb.append("0 tháng");
            }
        }
        return sb.toString();
    }

    private static String notesWithoutSalary(String notes) {
        if (notes == null || notes.isBlank()) {
            return null;
        }
        String cleaned = notes.replaceAll("(?i)\\s*\\|\\s*Mức lương:.*$", "").trim();
        return cleaned.isEmpty() ? null : cleaned;
    }

    private static String extractSalaryNote(String notes) {
        if (notes == null || notes.isBlank()) {
            return null;
        }
        int idx = notes.toLowerCase(Locale.ROOT).indexOf("mức lương:");
        if (idx < 0) {
            idx = notes.toLowerCase(Locale.ROOT).indexOf("muc luong:");
        }
        if (idx < 0) {
            return null;
        }
        String part = notes.substring(idx);
        int colon = part.indexOf(':');
        if (colon < 0 || colon + 1 >= part.length()) {
            return null;
        }
        String value = part.substring(colon + 1).trim();
        int pipe = value.indexOf('|');
        if (pipe >= 0) {
            value = value.substring(0, pipe).trim();
        }
        return value.isEmpty() ? null : value;
    }

    private static String firstNonBlank(String a, String b) {
        if (a != null && !a.isBlank()) {
            return a.trim();
        }
        if (b != null && !b.isBlank()) {
            return b.trim();
        }
        return null;
    }

    private static void setText(Row row, int col, String value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellStyle(style);
        if (value != null && !value.isBlank()) {
            cell.setCellValue(value.trim());
        }
    }

    private static void setNumber(Row row, int col, int value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellStyle(style);
        cell.setCellValue(value);
    }

    private static void setDate(Row row, int col, LocalDate value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellStyle(style);
        if (value != null) {
            cell.setCellValue(Date.from(value.atStartOfDay(VN).toInstant()));
        }
    }

    private static void autosize(Sheet sheet, int cols) {
        for (int i = 0; i < cols; i++) {
            sheet.autoSizeColumn(i);
            int width = sheet.getColumnWidth(i);
            sheet.setColumnWidth(i, Math.min(Math.max(width + 512, 3000), 12000));
        }
    }

    private static final class Styles {
        final CellStyle title;
        final CellStyle header;
        final CellStyle text;
        final CellStyle wrap;
        final CellStyle center;
        final CellStyle date;

        Styles(XSSFWorkbook wb) {
            CreationHelper helper = wb.getCreationHelper();

            XSSFFont titleFont = wb.createFont();
            titleFont.setBold(true);
            titleFont.setFontHeightInPoints((short) 12);
            title = wb.createCellStyle();
            title.setFont(titleFont);
            title.setVerticalAlignment(VerticalAlignment.CENTER);

            XSSFFont headerFont = wb.createFont();
            headerFont.setBold(true);
            headerFont.setColor(IndexedColors.WHITE.getIndex());
            header = wb.createCellStyle();
            header.setFont(headerFont);
            header.setFillForegroundColor(new XSSFColor(new byte[]{(byte) 15, (byte) 118, (byte) 110}, null));
            header.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            header.setAlignment(HorizontalAlignment.CENTER);
            header.setVerticalAlignment(VerticalAlignment.CENTER);
            header.setWrapText(true);
            setBorder(header);

            text = wb.createCellStyle();
            text.setVerticalAlignment(VerticalAlignment.CENTER);
            setBorder(text);

            wrap = wb.createCellStyle();
            wrap.cloneStyleFrom(text);
            wrap.setWrapText(true);

            center = wb.createCellStyle();
            center.cloneStyleFrom(text);
            center.setAlignment(HorizontalAlignment.CENTER);

            date = wb.createCellStyle();
            date.cloneStyleFrom(center);
            date.setDataFormat(helper.createDataFormat().getFormat("dd/mm/yyyy"));
        }

        private static void setBorder(CellStyle style) {
            style.setBorderTop(BorderStyle.THIN);
            style.setBorderBottom(BorderStyle.THIN);
            style.setBorderLeft(BorderStyle.THIN);
            style.setBorderRight(BorderStyle.THIN);
        }
    }
}
