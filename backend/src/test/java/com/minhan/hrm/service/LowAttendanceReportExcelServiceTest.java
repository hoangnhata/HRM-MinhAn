package com.minhan.hrm.service;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class LowAttendanceReportExcelServiceTest {

    private static Map<String, Object> row(long id, String name, String total) {
        Map<String, Object> m = new HashMap<>();
        m.put("employeeId", id);
        m.put("employeeCode", "NV" + id);
        m.put("fullName", name);
        m.put("department", "KHOA HỒI SỨC CẤP CỨU");
        m.put("position", "Điều dưỡng");
        m.put("employeeStatus", "ACTIVE");
        m.put("totalWorkUnits", new BigDecimal(total));
        m.put("clockedWorkUnits", new BigDecimal(total));
        return m;
    }

    @Test
    void showsStudyingAndMaternityInSpecialStatusColumn() throws Exception {
        AttendanceSummaryService summary = mock(AttendanceSummaryService.class);
        when(summary.monthReport(2026, 9, null)).thenReturn(List.of(
                row(1, "Nguyễn Thị Học", "0"),
                row(2, "Trần Thị Sản", "1"),
                row(3, "Lê Văn Thường", "3"),
                row(4, "Đủ Công", "26")));
        EmployeeRepository employees = mock(EmployeeRepository.class);
        when(employees.findAllById(any())).thenReturn(List.of(
                Employee.builder().id(1L).fullName("Nguyễn Thị Học").onTraining(true).build(),
                Employee.builder().id(2L).fullName("Trần Thị Sản").build(),
                Employee.builder().id(3L).fullName("Lê Văn Thường").build()));
        EmployeeWorkforceDetailsRepository details = mock(EmployeeWorkforceDetailsRepository.class);
        EmployeeWorkforceDetails maternity = new EmployeeWorkforceDetails();
        maternity.setEmployeeId(2L);
        maternity.setInsuranceParticipation("Nghỉ thai sản");
        when(details.findByEmployeeIn(anyList())).thenReturn(List.of(maternity));

        byte[] bytes = new LowAttendanceReportExcelService(summary, employees, details)
                .buildReport(2026, 9, null, new BigDecimal("5"));

        String out = System.getProperty("excelPreviewOut");
        if (out != null) {
            Files.write(Path.of(out), bytes);
        }
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(bytes))) {
            Sheet sh = wb.getSheetAt(0);
            assertTrue(sh.getRow(2).getCell(0).getStringCellValue()
                    .contains("trong đó 1 đang đi học, 1 nghỉ thai sản"));
            Row header = sh.getRow(4);
            assertEquals("Tình trạng đặc biệt", header.getCell(6).getStringCellValue());
            // Dải khoa ở dòng 5; nhân viên sắp tăng dần theo công.
            Row study = sh.getRow(6);
            Row maternityRow = sh.getRow(7);
            Row normal = sh.getRow(8);
            assertEquals("Nguyễn Thị Học", study.getCell(2).getStringCellValue());
            assertEquals("Đang đi học", study.getCell(6).getStringCellValue());
            assertEquals("Nghỉ thai sản", maternityRow.getCell(6).getStringCellValue());
            assertEquals("", normal.getCell(6).getStringCellValue());
            assertEquals("E0F2FE", ((XSSFCellStyle) study.getCell(6).getCellStyle())
                    .getFillForegroundXSSFColor().getARGBHex().substring(2));
            assertEquals("FCE7F3", ((XSSFCellStyle) maternityRow.getCell(6).getCellStyle())
                    .getFillForegroundXSSFColor().getARGBHex().substring(2));
        }
    }
}
