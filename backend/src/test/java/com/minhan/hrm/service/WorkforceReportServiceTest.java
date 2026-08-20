package com.minhan.hrm.service;

import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class WorkforceReportServiceTest {

    private static final LocalDate DATE = LocalDate.of(2026, 8, 4);
    private EmployeeRepository employeeRepository;
    private AttendanceRecordRepository attendanceRepository;
    private WorkforceReportService service;
    private Employee nurse;
    private Employee trialDoctor;

    @BeforeEach
    void setUp() {
        employeeRepository = mock(EmployeeRepository.class);
        attendanceRepository = mock(AttendanceRecordRepository.class);
        DepartmentRepository departmentRepository = mock(DepartmentRepository.class);
        service = new WorkforceReportService(employeeRepository, attendanceRepository, departmentRepository);
        Department department = Department.builder().id(1L).name("KHOA KHÁM BỆNH").build();
        when(departmentRepository.findAll(any(org.springframework.data.domain.Sort.class)))
                .thenReturn(List.of(department));
        nurse = employee(1L, "NV001", "Điều dưỡng A", "Điều dưỡng", EmployeeStatus.ACTIVE, department);
        trialDoctor = employee(2L, "TV002", "Bác sĩ B", "Bác sĩ", EmployeeStatus.PROBATION, department);
        when(employeeRepository.findAllWithDepartment()).thenReturn(List.of(nurse, trialDoctor));
    }

    @Test
    void hospitalReportMergesBacSyAndBacSiIntoOneColumn() {
        Department department = Department.builder().id(1L).name("KHOA KHÁM BỆNH").build();
        Employee doctorSi = employee(10L, "BS01", "BS Si", "Bác sĩ", EmployeeStatus.ACTIVE, department);
        Employee doctorSy = employee(11L, "BS02", "BS Sy", "Bác sỹ", EmployeeStatus.ACTIVE, department);
        when(employeeRepository.findAllWithDepartment()).thenReturn(List.of(doctorSi, doctorSy));

        Map<String, Object> report = service.hospitalReport();

        @SuppressWarnings("unchecked") Map<String, Integer> totals = (Map<String, Integer>) report.get("totals");
        assertEquals(2, totals.get("BAC_SI"));
        assertNull(totals.get("BAC_SY"));
        assertEquals(0, totals.get("BAC_SI_THU_VIEC"));
        assertEquals(0, totals.get("NHAN_VIEN_THU_VIEC"));
        @SuppressWarnings("unchecked") List<Map<String, String>> categories =
                (List<Map<String, String>>) report.get("categories");
        assertEquals(List.of("Bác sĩ", "Bác sĩ thử việc", "Nhân viên thử việc"),
                categories.stream().map(c -> c.get("label")).toList());
        assertEquals("Bác sĩ", WorkforceReportService.reportPositionLabel("Bác sỹ"));
        assertEquals("Bác sĩ", WorkforceReportService.reportPositionLabel("Bác sĩ"));
    }

    @Test
    void hospitalReportCountsByActualPositionTitle() {
        Map<String, Object> report = service.hospitalReport();

        assertEquals(2, report.get("grandTotal"));
        @SuppressWarnings("unchecked") Map<String, Integer> totals = (Map<String, Integer>) report.get("totals");
        assertEquals(1, totals.get("DIEU_DUONG"));
        assertNull(totals.get("BAC_SI"));
        assertEquals(1, totals.get("BAC_SI_THU_VIEC"));
        assertEquals(0, totals.get("NHAN_VIEN_THU_VIEC"));
        @SuppressWarnings("unchecked") List<Map<String, String>> categories =
                (List<Map<String, String>>) report.get("categories");
        assertEquals(List.of("Điều dưỡng", "Bác sĩ thử việc", "Nhân viên thử việc"),
                categories.stream().map(c -> c.get("label")).toList());
    }

    @Test
    void hospitalReportSplitsNonDoctorProbationIntoStaffTrialColumn() {
        Department department = Department.builder().id(1L).name("KHOA KHÁM BỆNH").build();
        Employee trialNurse = employee(3L, "TV003", "Điều dưỡng C", "Điều dưỡng",
                EmployeeStatus.PROBATION, department);
        Employee internIt = employee(4L, "TT004", "NV IT", "Nhân viên IT",
                EmployeeStatus.INTERN, department);
        when(employeeRepository.findAllWithDepartment())
                .thenReturn(List.of(nurse, trialDoctor, trialNurse, internIt));

        Map<String, Object> report = service.hospitalReport();

        @SuppressWarnings("unchecked") Map<String, Integer> totals = (Map<String, Integer>) report.get("totals");
        assertEquals(1, totals.get("DIEU_DUONG"));
        assertEquals(1, totals.get("BAC_SI_THU_VIEC"));
        assertEquals(2, totals.get("NHAN_VIEN_THU_VIEC"));
        assertEquals(4, report.get("grandTotal"));
    }

    @Test
    void dailyReportCountsOnlyEmployeesActuallyWorking() {
        AttendanceRecord present = attendance(nurse, "PRESENT", new BigDecimal("1.0"));
        AttendanceRecord leave = attendance(trialDoctor, "LEAVE", BigDecimal.ONE);
        when(attendanceRepository.findByWorkDateBetweenWithEmployee(DATE, DATE))
                .thenReturn(List.of(present, leave));

        Map<String, Object> report = service.dailyReport(DATE);

        assertEquals(1, report.get("grandTotal"));
        @SuppressWarnings("unchecked") Map<String, Integer> totals = (Map<String, Integer>) report.get("totals");
        assertEquals(1, totals.get("DIEU_DUONG"));
        assertNull(totals.get("BAC_SI"));
    }

    @Test
    void dailyReportCountsEmployeeImmediatelyAfterMorningCheckIn() {
        AttendanceRecord justCheckedIn = attendance(nurse, "ABSENT", BigDecimal.ZERO);
        justCheckedIn.setMorningCheckIn(LocalTime.of(6, 45));
        justCheckedIn.setMorningCheckOut(LocalTime.of(6, 48)); // quẹt lại buổi sáng
        justCheckedIn.setCheckIn(LocalTime.of(6, 45));
        justCheckedIn.setCheckOut(LocalTime.of(6, 48));
        when(attendanceRepository.findByWorkDateBetweenWithEmployee(DATE, DATE))
                .thenReturn(List.of(justCheckedIn));

        Map<String, Object> report = service.dailyReport(DATE);

        assertEquals(1, report.get("grandTotal"));
        @SuppressWarnings("unchecked") Map<String, Integer> totals = (Map<String, Integer>) report.get("totals");
        assertEquals(1, totals.get("DIEU_DUONG"));
        @SuppressWarnings("unchecked") List<Map<String, Object>> details =
                (List<Map<String, Object>>) report.get("details");
        assertEquals("06:45", details.get(0).get("checkIn"));
        assertNull(details.get(0).get("checkOut"));
    }

    @Test
    void dailyReportIgnoresMorningRescanAsCheckOut() {
        AttendanceRecord row = attendance(nurse, "ABSENT", BigDecimal.ZERO);
        row.setMorningCheckIn(LocalTime.of(6, 35));
        row.setMorningCheckOut(LocalTime.of(6, 38)); // sợ máy không nhận → quẹt lại
        row.setCheckIn(LocalTime.of(6, 35));
        row.setCheckOut(LocalTime.of(6, 38));
        when(attendanceRepository.findByWorkDateBetweenWithEmployee(DATE, DATE))
                .thenReturn(List.of(row));

        Map<String, Object> report = service.dailyReport(DATE);

        @SuppressWarnings("unchecked") List<Map<String, Object>> details =
                (List<Map<String, Object>>) report.get("details");
        assertEquals("06:35", details.get(0).get("checkIn"));
        assertNull(details.get(0).get("checkOut"));
    }

    @Test
    void dailyReportUsesAfternoonCheckOutOnly() {
        AttendanceRecord row = attendance(nurse, "PRESENT", BigDecimal.ONE);
        row.setMorningCheckIn(LocalTime.of(6, 36));
        row.setMorningCheckOut(LocalTime.of(6, 40)); // quẹt lại sáng — bỏ
        row.setAfternoonCheckIn(LocalTime.of(13, 5));
        row.setAfternoonCheckOut(LocalTime.of(17, 15));
        when(attendanceRepository.findByWorkDateBetweenWithEmployee(DATE, DATE))
                .thenReturn(List.of(row));

        Map<String, Object> report = service.dailyReport(DATE);

        @SuppressWarnings("unchecked") List<Map<String, Object>> details =
                (List<Map<String, Object>>) report.get("details");
        assertEquals("06:36", details.get(0).get("checkIn"));
        assertEquals("17:15", details.get(0).get("checkOut"));
    }

    @Test
    void dailyReportContinuousShiftUsesDayInAndDayOut() {
        // Ca thông tầm: morningCheckIn + afternoonCheckOut (không có ca giữa trưa)
        AttendanceRecord row = attendance(nurse, "PRESENT", BigDecimal.ONE);
        row.setMorningCheckIn(LocalTime.of(7, 0));
        row.setMorningCheckOut(null);
        row.setAfternoonCheckIn(null);
        row.setAfternoonCheckOut(LocalTime.of(16, 0));
        when(attendanceRepository.findByWorkDateBetweenWithEmployee(DATE, DATE))
                .thenReturn(List.of(row));

        Map<String, Object> report = service.dailyReport(DATE);

        @SuppressWarnings("unchecked") List<Map<String, Object>> details =
                (List<Map<String, Object>>) report.get("details");
        assertEquals("07:00", details.get(0).get("checkIn"));
        assertEquals("16:00", details.get(0).get("checkOut"));
    }

    @Test
    void exportedWorkbookContainsMatrixAndDetailSheets() throws Exception {
        byte[] file = service.exportHospitalExcel();

        assertTrue(file.length > 1000);
        try (XSSFWorkbook workbook = new XSSFWorkbook(new ByteArrayInputStream(file))) {
            assertEquals("Nhân lực toàn viện", workbook.getSheetAt(0).getSheetName());
            assertEquals("Chi tiết nhân viên", workbook.getSheetAt(1).getSheetName());
            assertEquals("BÁO CÁO NHÂN LỰC TOÀN VIỆN", workbook.getSheetAt(0).getRow(0).getCell(0).getStringCellValue());
            assertTrue(workbook.getSheetAt(0).getNumMergedRegions() >= 2);
            assertEquals("TỔNG", workbook.getSheetAt(0).getRow(5).getCell(4).getStringCellValue());
            assertTrue(workbook.getSheetAt(0).getPaneInformation().isFreezePane());
            assertTrue(workbook.getSheetAt(0).getPrintSetup().getLandscape());
            assertTrue(workbook.getSheetAt(0).getCTWorksheet().isSetAutoFilter());
            assertEquals("Chức vụ", workbook.getSheetAt(1).getRow(3).getCell(4).getStringCellValue());
            assertEquals(workbook.getSheetAt(0).getRow(0).getCell(0).getCellStyle().getFillForegroundColorColor(),
                    workbook.getSheetAt(1).getRow(0).getCell(0).getCellStyle().getFillForegroundColorColor());
        }
    }

    @Test
    void dailyExportBuildsDynamicPositionColumnsAndAddsAttendanceDetail() throws Exception {
        when(attendanceRepository.findByWorkDateBetweenWithEmployee(DATE, DATE))
                .thenReturn(List.of(attendance(nurse, "PRESENT", BigDecimal.ONE)));

        byte[] file = service.exportDailyExcel(DATE);

        try (XSSFWorkbook workbook = new XSSFWorkbook(new ByteArrayInputStream(file))) {
            assertEquals("BÁO CÁO NHÂN LỰC ĐI LÀM HẰNG NGÀY  •  04/08/2026",
                    workbook.getSheetAt(0).getRow(0).getCell(0).getStringCellValue());
            assertTrue(workbook.getSheetAt(0).getRow(2).getCell(0).getStringCellValue().contains("THỰC TẾ CÓ MẶT"));
            assertEquals("TỔNG", workbook.getSheetAt(0).getRow(5).getCell(4).getStringCellValue());
            assertEquals("Trạng thái công", workbook.getSheetAt(1).getRow(3).getCell(10).getStringCellValue());
            assertEquals("0.00", workbook.getSheetAt(1).getRow(4).getCell(8).getCellStyle().getDataFormatString());
            assertTrue(workbook.getSheetAt(1).getPaneInformation().isFreezePane());
        }
    }

    private static Employee employee(Long id, String code, String name, String position,
                                     EmployeeStatus status, Department department) {
        return Employee.builder().id(id).employeeCode(code).fullName(name).department(department)
                .position(Position.builder().id(id).code("P" + id).title(position).build())
                .status(status).employmentType(EmploymentType.FULL_TIME).hireDate(DATE.minusYears(1)).build();
    }

    private static AttendanceRecord attendance(Employee employee, String status, BigDecimal units) {
        return AttendanceRecord.builder().employee(employee).workDate(DATE).status(status)
                .morningWorkUnits(units).afternoonWorkUnits(BigDecimal.ZERO)
                .overtimeWorkUnits(BigDecimal.ZERO).build();
    }
}
