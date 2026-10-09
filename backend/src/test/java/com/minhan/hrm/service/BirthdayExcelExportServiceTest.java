package com.minhan.hrm.service;

import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.Position;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class BirthdayExcelExportServiceTest {

    private static Employee emp(String name, LocalDate dob, EmployeeStatus status, String dept) {
        return Employee.builder()
                .fullName(name)
                .employeeCode("NV-" + name.length())
                .gender(name.startsWith("Trần") ? "Nam" : "Nữ")
                .dateOfBirth(dob)
                .status(status)
                .phone("0912345678")
                .department(Department.builder().name(dept).build())
                .position(Position.builder().title("Điều dưỡng").build())
                .build();
    }

    @Test
    void groupsByMonthSortedByDayAndSkipsTerminatedOrMissingDob() throws Exception {
        int year = LocalDate.now().getYear();
        EmployeeRepository repo = mock(EmployeeRepository.class);
        when(repo.findAllWithDepartment()).thenReturn(List.of(
                emp("Nguyễn Thị Hoa", LocalDate.of(1990, 9, 21), EmployeeStatus.ACTIVE, "KHOA HỒI SỨC CẤP CỨU"),
                emp("Trần Văn Nam", LocalDate.of(year - 40, 9, 3), EmployeeStatus.ACTIVE, "KHOA KHÁM BỆNH"),
                emp("Lê Thị Mai", LocalDate.of(1998, 10, 15), EmployeeStatus.PROBATION, "KHOA NỘI"),
                emp("Phạm Thị Lan", LocalDate.of(1985, 9, 30), EmployeeStatus.TERMINATED, "KHOA NỘI"),
                emp("Đỗ Văn An", null, EmployeeStatus.ACTIVE, "KHOA NGOẠI"),
                emp("Vũ Thị Hồng", LocalDate.of(1992, 3, 8), EmployeeStatus.ACTIVE, "KHOA SẢN")));

        byte[] bytes = new BirthdayExcelExportService(repo).export(List.of(10, 9));

        String out = System.getProperty("excelPreviewOut");
        if (out != null) {
            Files.write(Path.of(out), bytes);
        }
        try (XSSFWorkbook wb = new XSSFWorkbook(new ByteArrayInputStream(bytes))) {
            Sheet sh = wb.getSheetAt(0);
            assertTrue(sh.getRow(1).getCell(0).getStringCellValue().contains("THÁNG 9, 10/" + year));
            assertEquals("THÁNG 9  ·  2 người", sh.getRow(5).getCell(0).getStringCellValue());
            // Trong tháng 9 sắp theo ngày: 03/09 trước 21/09; người đã nghỉ việc (30/09) không có.
            assertEquals("Trần Văn Nam", sh.getRow(6).getCell(1).getStringCellValue());
            assertEquals(40.0, sh.getRow(6).getCell(6).getNumericCellValue());
            assertEquals("Nguyễn Thị Hoa", sh.getRow(7).getCell(1).getStringCellValue());
            assertEquals("THÁNG 10  ·  1 người", sh.getRow(8).getCell(0).getStringCellValue());
            assertEquals("Thử việc", sh.getRow(9).getCell(9).getStringCellValue());
            assertTrue(sh.getRow(11).getCell(0).getStringCellValue().contains("1 nhân sự chưa nhập ngày sinh"));
        }
    }

    @Test
    void rejectsEmptyMonthSelection() {
        BirthdayExcelExportService service = new BirthdayExcelExportService(mock(EmployeeRepository.class));
        assertThrows(ApiException.class, () -> service.export(List.of()));
        assertThrows(ApiException.class, () -> service.export(List.of(13)));
    }
}
