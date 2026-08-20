package com.minhan.hrm.service;

import com.minhan.hrm.dto.salary.ComputedSalaryGradeDto;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.EmployeeSalaryProfileRepository;
import com.minhan.hrm.repository.SalaryInfoRepository;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.*;

@Service
@RequiredArgsConstructor
public class SalaryGradeReviewService {

    private final EmployeeSalaryProfileRepository profileRepository;
    private final SalaryInfoRepository salaryInfoRepository;
    private final SalaryCalculatorService calculator;
    private final SalaryAccessService salaryAccessService;

    @Transactional(readOnly = true)
    public Map<String, Object> list(int year, int month, String salaryToken) {
        salaryAccessService.requireAdminGrant(salaryToken);
        YearMonth period = YearMonth.of(year, month);
        LocalDate from = period.atDay(1);
        LocalDate to = period.atEndOfMonth();
        LocalDate today = LocalDate.now();
        List<Map<String, Object>> rows = profileRepository.findAll().stream()
                .filter(p -> p.getEmployee() != null)
                .filter(p -> p.getEmployee().getStatus() != EmployeeStatus.TERMINATED)
                .filter(p -> p.getSalaryCategory() != null && !p.isLdg())
                .map(p -> buildRow(p, from, to, today))
                .filter(Objects::nonNull)
                .sorted(Comparator
                        .comparing((Map<String, Object> r) -> (LocalDate) r.get("effectiveDate"))
                        .thenComparing(r -> String.valueOf(r.get("department")), String.CASE_INSENSITIVE_ORDER)
                        .thenComparing(r -> String.valueOf(r.get("fullName")), String.CASE_INSENSITIVE_ORDER))
                .toList();

        long upcoming = rows.stream().filter(r -> "UPCOMING".equals(r.get("timingStatus"))).count();
        long todayCount = rows.stream().filter(r -> "TODAY".equals(r.get("timingStatus"))).count();
        long passed = rows.stream().filter(r -> "PASSED".equals(r.get("timingStatus"))).count();
        BigDecimal increaseTotal = rows.stream()
                .map(r -> (BigDecimal) r.get("increaseAmount"))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("year", year);
        out.put("month", month);
        out.put("generatedAt", today);
        out.put("total", rows.size());
        out.put("upcoming", upcoming);
        out.put("today", todayCount);
        out.put("passed", passed);
        out.put("increaseTotal", increaseTotal);
        out.put("rows", rows);
        return out;
    }

    private Map<String, Object> buildRow(
            EmployeeSalaryProfile profile, LocalDate from, LocalDate to, LocalDate today) {
        Employee emp = profile.getEmployee();
        LocalDate effectiveDate = findComputedRaiseDate(emp, profile, from, to);
        SalaryInfo salaryInfo = salaryInfoRepository.findByEmployee(emp).orElse(null);
        boolean manualReviewDate = false;
        if (effectiveDate == null && salaryInfo != null && salaryInfo.getNextReviewDate() != null
                && !salaryInfo.getNextReviewDate().isBefore(from)
                && !salaryInfo.getNextReviewDate().isAfter(to)) {
            effectiveDate = salaryInfo.getNextReviewDate();
            manualReviewDate = true;
        }
        if (effectiveDate == null) return null;

        ComputedSalaryGradeDto current = calculator.computeForProfileAtDate(emp, profile, effectiveDate.minusDays(1));
        ComputedSalaryGradeDto next = calculator.computeForProfileAtDate(emp, profile, effectiveDate);
        if (manualReviewDate && next.getGradeLevel() <= current.getGradeLevel()) {
            next = expectedNextGrade(profile, current, effectiveDate);
        }
        BigDecimal currentSalary = salaryValue(current, profile);
        BigDecimal nextSalary = salaryValue(next, profile);
        BigDecimal increase = nextSalary.subtract(currentSalary).max(BigDecimal.ZERO);
        BigDecimal percent = currentSalary.compareTo(BigDecimal.ZERO) > 0
                ? increase.multiply(BigDecimal.valueOf(100)).divide(currentSalary, 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        long daysUntil = ChronoUnit.DAYS.between(today, effectiveDate);

        Map<String, Object> row = new LinkedHashMap<>();
        row.put("employeeId", emp.getId());
        row.put("employeeCode", nullToEmpty(emp.getEmployeeCode()));
        row.put("fullName", emp.getFullName());
        row.put("department", emp.getDepartment() != null ? emp.getDepartment().getName() : "");
        row.put("position", emp.getPosition() != null ? emp.getPosition().getTitle() : "");
        row.put("salaryCategory", profile.getSalaryCategory().name());
        row.put("employeeBlock", profile.getEmployeeBlock() != null ? profile.getEmployeeBlock().name() : "");
        row.put("qualification", profile.getSalaryCategory() == SalaryCategory.DOCTOR
                ? nullToEmpty(profile.getDoctorQualificationCode())
                : nullToEmpty(calculator.resolveQualification(profile)));
        row.put("effectiveDate", effectiveDate);
        row.put("lastRaiseDate", salaryInfo != null ? salaryInfo.getLastRaiseDate() : null);
        row.put("reviewSource", manualReviewDate ? "MANUAL_REVIEW_DATE" : "SENIORITY_SCALE");
        row.put("seniorityYears", calculator.resolveSeniorityYears(emp, profile, effectiveDate));
        row.put("currentGradeLevel", current.getGradeLevel());
        row.put("currentGrade", current.getGradeLabel());
        row.put("nextGradeLevel", next.getGradeLevel());
        row.put("nextGrade", next.getGradeLabel());
        row.put("currentSalary", currentSalary);
        row.put("nextSalary", nextSalary);
        row.put("increaseAmount", increase);
        row.put("increasePercent", percent);
        row.put("daysUntil", daysUntil);
        row.put("timingStatus", daysUntil > 0 ? "UPCOMING" : daysUntil == 0 ? "TODAY" : "PASSED");
        return row;
    }

    private LocalDate findComputedRaiseDate(
            Employee emp, EmployeeSalaryProfile profile, LocalDate from, LocalDate to) {
        int previous = calculator.computeForProfileAtDate(emp, profile, from.minusDays(1)).getGradeLevel();
        for (LocalDate date = from; !date.isAfter(to); date = date.plusDays(1)) {
            int grade = calculator.computeForProfileAtDate(emp, profile, date).getGradeLevel();
            if (grade > previous) return date;
            previous = grade;
        }
        return null;
    }

    private ComputedSalaryGradeDto expectedNextGrade(
            EmployeeSalaryProfile profile, ComputedSalaryGradeDto current, LocalDate effectiveDate) {
        if (profile.getSalaryCategory() == SalaryCategory.EMPLOYEE && profile.getEmployeeBlock() != null) {
            SalaryScaleType type = profile.getEmployeeBlock() == EmployeeSalaryBlock.DIRECT
                    ? SalaryScaleType.EMPLOYEE_DIRECT : SalaryScaleType.EMPLOYEE_INDIRECT;
            return calculator.findEmployeeGrade(
                    type, calculator.resolveQualification(profile), Math.min(10, current.getGradeLevel() + 1));
        }
        return calculator.computeDoctorGrade(
                profile.getDoctorQualificationCode(),
                calculator.resolveSeniorityYears(profile.getEmployee(), profile, effectiveDate.plusYears(2)));
    }

    private static BigDecimal salaryValue(ComputedSalaryGradeDto grade, EmployeeSalaryProfile profile) {
        BigDecimal scale = grade.getScaleSalary() != null ? grade.getScaleSalary() : BigDecimal.ZERO;
        if (scale.compareTo(BigDecimal.ZERO) > 0) return scale;
        BigDecimal insurance = grade.getInsuranceSalary() != null ? grade.getInsuranceSalary() : BigDecimal.ZERO;
        BigDecimal product = grade.getProductSalary() != null ? grade.getProductSalary() : BigDecimal.ZERO;
        BigDecimal split = insurance.add(product);
        if (split.compareTo(BigDecimal.ZERO) > 0) return split;
        return zero(profile.getImportedInsuranceSalary()).add(zero(profile.getImportedProductSalary()));
    }

    @Transactional(readOnly = true)
    @SuppressWarnings("unchecked")
    public byte[] exportExcel(int year, int month, String salaryToken) {
        Map<String, Object> report = list(year, month, salaryToken);
        List<Map<String, Object>> rows = (List<Map<String, Object>>) report.get("rows");
        try (Workbook workbook = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sheet = workbook.createSheet("Nâng bậc " + month + "-" + year);
            sheet.createFreezePane(0, 3);
            CellStyle title = workbook.createCellStyle();
            Font titleFont = workbook.createFont();
            titleFont.setBold(true); titleFont.setFontHeightInPoints((short) 15);
            title.setFont(titleFont); title.setAlignment(HorizontalAlignment.CENTER);
            Row titleRow = sheet.createRow(0);
            Cell titleCell = titleRow.createCell(0);
            titleCell.setCellValue("DANH SÁCH NHÂN VIÊN NÂNG BẬC LƯƠNG THÁNG " + month + "/" + year);
            titleCell.setCellStyle(title);

            String[] headers = {"STT", "Mã NV", "Họ và tên", "Khoa/phòng", "Chức vụ", "Đối tượng",
                    "Trình độ", "Ngày nâng bậc", "Thâm niên (năm)", "Bậc hiện tại", "Bậc dự kiến",
                    "Lương hiện tại", "Lương dự kiến", "Chênh lệch", "Tỷ lệ tăng", "Trạng thái", "Nguồn xác định"};
            sheet.addMergedRegion(new org.apache.poi.ss.util.CellRangeAddress(0, 0, 0, headers.length - 1));
            CellStyle header = workbook.createCellStyle();
            header.setFillForegroundColor(IndexedColors.TEAL.getIndex());
            header.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            header.setAlignment(HorizontalAlignment.CENTER);
            header.setVerticalAlignment(VerticalAlignment.CENTER);
            header.setWrapText(true);
            Font headerFont = workbook.createFont(); headerFont.setBold(true); headerFont.setColor(IndexedColors.WHITE.getIndex());
            header.setFont(headerFont);
            Row headerRow = sheet.createRow(2);
            for (int i = 0; i < headers.length; i++) { Cell c = headerRow.createCell(i); c.setCellValue(headers[i]); c.setCellStyle(header); }

            CellStyle money = workbook.createCellStyle(); money.setDataFormat(workbook.createDataFormat().getFormat("#,##0\" đ\""));
            CellStyle date = workbook.createCellStyle(); date.setDataFormat(workbook.createDataFormat().getFormat("dd/mm/yyyy"));
            int index = 3;
            for (Map<String, Object> data : rows) {
                Row row = sheet.createRow(index++); int c = 0;
                row.createCell(c++).setCellValue(index - 3);
                row.createCell(c++).setCellValue(String.valueOf(data.get("employeeCode")));
                row.createCell(c++).setCellValue(String.valueOf(data.get("fullName")));
                row.createCell(c++).setCellValue(String.valueOf(data.get("department")));
                row.createCell(c++).setCellValue(String.valueOf(data.get("position")));
                row.createCell(c++).setCellValue(categoryLabel(String.valueOf(data.get("salaryCategory")), String.valueOf(data.get("employeeBlock"))));
                row.createCell(c++).setCellValue(String.valueOf(data.get("qualification")));
                Cell dc = row.createCell(c++); dc.setCellValue((LocalDate) data.get("effectiveDate")); dc.setCellStyle(date);
                row.createCell(c++).setCellValue(((BigDecimal) data.get("seniorityYears")).doubleValue());
                row.createCell(c++).setCellValue(String.valueOf(data.get("currentGrade")));
                row.createCell(c++).setCellValue(String.valueOf(data.get("nextGrade")));
                Cell m1 = row.createCell(c++); m1.setCellValue(((BigDecimal) data.get("currentSalary")).doubleValue()); m1.setCellStyle(money);
                Cell m2 = row.createCell(c++); m2.setCellValue(((BigDecimal) data.get("nextSalary")).doubleValue()); m2.setCellStyle(money);
                Cell m3 = row.createCell(c++); m3.setCellValue(((BigDecimal) data.get("increaseAmount")).doubleValue()); m3.setCellStyle(money);
                row.createCell(c++).setCellValue(((BigDecimal) data.get("increasePercent")).doubleValue() / 100d);
                row.createCell(c++).setCellValue(statusLabel(String.valueOf(data.get("timingStatus"))));
                row.createCell(c).setCellValue("MANUAL_REVIEW_DATE".equals(data.get("reviewSource")) ? "Ngày xét lương hồ sơ" : "Thâm niên/thang lương");
            }
            for (int i = 0; i < headers.length; i++) { sheet.autoSizeColumn(i); sheet.setColumnWidth(i, Math.min(sheet.getColumnWidth(i) + 700, 16000)); }
            workbook.write(out); return out.toByteArray();
        } catch (Exception e) {
            throw new IllegalStateException("Không tạo được file nâng bậc lương", e);
        }
    }

    private static String categoryLabel(String category, String block) {
        if ("DOCTOR".equals(category)) return "Bác sĩ";
        return "DIRECT".equals(block) ? "NV trực tiếp" : "NV gián tiếp";
    }
    private static String statusLabel(String status) {
        return "TODAY".equals(status) ? "Đến hạn hôm nay" : "PASSED".equals(status) ? "Đã đến hạn" : "Sắp đến hạn";
    }
    private static BigDecimal zero(BigDecimal value) { return value != null ? value : BigDecimal.ZERO; }
    private static String nullToEmpty(String value) { return value != null ? value : ""; }
}
