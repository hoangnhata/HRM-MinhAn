package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceDayProcessor;
import com.minhan.hrm.attendance.ForgotPenaltySettings;
import com.minhan.hrm.attendance.LatePenaltySettings;
import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeSalaryProfile;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.SalaryCategory;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.AttendanceWorkRequestRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeSalaryProfileRepository;
import com.minhan.hrm.repository.SeminarProposalRequestRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AttendanceSummaryServiceReportScopeTest {

    @Mock
    private AttendanceRecordRepository attendanceRecordRepository;
    @Mock
    private AttendanceWorkRequestRepository workRequestRepository;
    @Mock
    private EmployeeRepository employeeRepository;
    @Mock
    private EmployeeService employeeService;
    @Mock
    private AttendanceShiftScheduleService shiftScheduleService;
    @Mock
    private ForgotPenaltyConfigService forgotPenaltyConfigService;
    @Mock
    private LatePenaltyConfigService latePenaltyConfigService;
    @Mock
    private AttendanceDayProcessor dayProcessor;
    @Mock
    private DutyShiftService dutyShiftService;
    @Mock
    private SeminarProposalRequestRepository seminarProposalRepository;
    @Mock
    private EmployeeSalaryProfileRepository salaryProfileRepository;
    @Mock
    private YoungChildHoursService youngChildHoursService;

    @InjectMocks
    private AttendanceSummaryService service;

    private Department ownDepartment;
    private Department otherDepartment;
    private Employee ownEmployee;
    private Employee otherEmployee;

    @BeforeEach
    void setUp() {
        ownDepartment = Department.builder().id(10L).code("OWN").name("Khoa của trưởng khoa").build();
        otherDepartment = Department.builder().id(20L).code("OTHER").name("Khoa khác").build();
        ownEmployee = employee(1L, "NV001", "Nhân viên khoa mình", ownDepartment);
        otherEmployee = employee(2L, "NV002", "Nhân viên khoa khác", otherDepartment);

        org.mockito.Mockito.lenient()
                .when(employeeRepository.findAll())
                .thenReturn(List.of(ownEmployee, otherEmployee));
        org.mockito.Mockito.lenient()
                .when(attendanceRecordRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
                        any(Employee.class), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of());
        when(latePenaltyConfigService.currentSettings()).thenReturn(LatePenaltySettings.defaults());
        when(forgotPenaltyConfigService.currentSettings()).thenReturn(ForgotPenaltySettings.defaults());
        when(workRequestRepository.findByEmployeeIdAndWorkDateBetween(
                anyLong(), any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of());
        when(dutyShiftService.findEntriesForEmployee(
                anyLong(), any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of());
        when(dutyShiftService.rollup(any(Employee.class), anyList())).thenReturn(Map.of(
                "dutyBonusTotal", BigDecimal.ZERO,
                "dutyPostPayTotal", BigDecimal.ZERO,
                "dutyWorkUnitsTotal", BigDecimal.ZERO,
                "dutyShiftCount", 0));
        org.mockito.Mockito.lenient()
                .when(dutyShiftService.reportEntries(any(Employee.class), anyList()))
                .thenReturn(List.of());
        when(seminarProposalRepository.findApprovedWithSupportInPeriod(
                anyLong(), any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of());
        org.mockito.Mockito.lenient()
                .when(salaryProfileRepository.findByEmployee(any(Employee.class)))
                .thenReturn(Optional.empty());
        org.mockito.Mockito.lenient()
                .when(youngChildHoursService.datesForEmployee(
                        anyLong(), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(Set.of());
    }

    @Test
    void headDepartmentAlwaysExportsOwnDepartmentEvenWhenRequestingAnotherDepartment() {
        UserAccount head = UserAccount.builder()
                .username("head")
                .role(UserRole.HEAD_DEPARTMENT)
                .build();
        when(employeeService.currentUser()).thenReturn(head);
        when(employeeService.resolveHeadDepartmentScope(head)).thenReturn(ownDepartment.getId());

        List<Map<String, Object>> rows = service.monthReport(2026, 7, otherDepartment.getId());

        assertEquals(1, rows.size());
        assertEquals("NV001", rows.get(0).get("employeeCode"));
        assertEquals(ownDepartment.getName(), rows.get(0).get("department"));
        verify(employeeService).resolveHeadDepartmentScope(head);
        verify(attendanceRecordRepository).findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
                eq(ownEmployee), any(LocalDate.class), any(LocalDate.class));
        verify(attendanceRecordRepository, never()).findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
                eq(otherEmployee), any(LocalDate.class), any(LocalDate.class));
    }

    @Test
    void adminStillExportsRequestedDepartment() {
        UserAccount admin = UserAccount.builder()
                .username("admin")
                .role(UserRole.ADMIN)
                .build();
        when(employeeService.currentUser()).thenReturn(admin);

        List<Map<String, Object>> rows = service.monthReport(2026, 7, otherDepartment.getId());

        assertEquals(1, rows.size());
        assertEquals("NV002", rows.get(0).get("employeeCode"));
        assertEquals(otherDepartment.getName(), rows.get(0).get("department"));
        verify(employeeService, never()).resolveHeadDepartmentScope(any(UserAccount.class));
    }

    @Test
    void doctorReceivesOneHundredThousandForEachQuangTrungDay() {
        when(employeeService.requireEmployeeEntity(ownEmployee.getId())).thenReturn(ownEmployee);
        when(attendanceRecordRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
                eq(ownEmployee), any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of(
                quangTrungRecord(ownEmployee, LocalDate.of(2026, 7, 1)),
                quangTrungRecord(ownEmployee, LocalDate.of(2026, 7, 2))));
        when(salaryProfileRepository.findByEmployee(ownEmployee)).thenReturn(Optional.of(
                EmployeeSalaryProfile.builder()
                        .employee(ownEmployee)
                        .salaryCategory(SalaryCategory.DOCTOR)
                        .build()));

        Map<String, Object> summary = service.employeeMonthSummary(ownEmployee.getId(), 2026, 7);

        assertEquals(new BigDecimal("200000"), summary.get("quangTrungAllowance"));
        assertEquals(new BigDecimal("100000"), summary.get("quangTrungAllowanceRate"));
        assertEquals(2, summary.get("quangTrungAllowanceCount"));
    }

    @Test
    void regularEmployeeReceivesFiftyThousandForEachQuangTrungDay() {
        when(employeeService.requireEmployeeEntity(ownEmployee.getId())).thenReturn(ownEmployee);
        when(attendanceRecordRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
                eq(ownEmployee), any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of(
                quangTrungRecord(ownEmployee, LocalDate.of(2026, 7, 1))));

        Map<String, Object> summary = service.employeeMonthSummary(ownEmployee.getId(), 2026, 7);

        assertEquals(new BigDecimal("50000"), summary.get("quangTrungAllowance"));
        assertEquals(new BigDecimal("50000"), summary.get("quangTrungAllowanceRate"));
        assertEquals(1, summary.get("quangTrungAllowanceCount"));
    }

    @Test
    void summarySeparatesClockedWorkFromPaidLeave() {
        when(employeeService.requireEmployeeEntity(ownEmployee.getId())).thenReturn(ownEmployee);
        when(attendanceRecordRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
                eq(ownEmployee), any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of(
                attendanceRecord(ownEmployee, LocalDate.of(2026, 7, 1), "PRESENT", "0.67", "0.33"),
                attendanceRecord(ownEmployee, LocalDate.of(2026, 7, 2), "LEAVE", "0.67", "0.33")));

        Map<String, Object> summary = service.employeeMonthSummary(ownEmployee.getId(), 2026, 7);

        assertEquals(0, ((BigDecimal) summary.get("attendanceWorkUnits"))
                .compareTo(new BigDecimal("2.00")));
        assertEquals(0, ((BigDecimal) summary.get("clockedWorkUnits"))
                .compareTo(new BigDecimal("1.00")));
        assertEquals(0, ((BigDecimal) summary.get("leaveWorkUnits"))
                .compareTo(new BigDecimal("1.00")));
    }

    private static Employee employee(Long id, String code, String name, Department department) {
        return Employee.builder()
                .id(id)
                .employeeCode(code)
                .fullName(name)
                .status(EmployeeStatus.ACTIVE)
                .department(department)
                .build();
    }

    private static com.minhan.hrm.entity.AttendanceRecord quangTrungRecord(
            Employee employee, LocalDate workDate) {
        return com.minhan.hrm.entity.AttendanceRecord.builder()
                .employee(employee)
                .workDate(workDate)
                .status("PRESENT")
                .note(AttendanceService.QUANG_TRUNG_NOTE_MARKER)
                .build();
    }

    private static AttendanceRecord attendanceRecord(
            Employee employee,
            LocalDate workDate,
            String status,
            String morningUnits,
            String afternoonUnits) {
        return AttendanceRecord.builder()
                .employee(employee)
                .workDate(workDate)
                .status(status)
                .morningWorkUnits(new BigDecimal(morningUnits))
                .afternoonWorkUnits(new BigDecimal(afternoonUnits))
                .build();
    }
}
