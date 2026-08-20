package com.minhan.hrm.service;

import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HeadPendingNotificationScopeTest {

    @Mock
    private EmployeeLinkService employeeLinkService;
    @Mock
    private EmployeeWorkforceDetailsRepository employeeWorkforceDetailsRepository;

    @InjectMocks
    private EmployeeService employeeService;

    private Department deptA;
    private Department deptB;
    private Employee staffInUnit1;
    private UserAccount admin;
    private UserAccount headDept;
    private UserAccount headUnit1;
    private UserAccount headUnit2;

    @BeforeEach
    void setUp() {
        deptA = Department.builder().id(1L).name("Khoa A").build();
        deptB = Department.builder().id(2L).name("Khoa B").build();
        staffInUnit1 = Employee.builder().id(10L).fullName("NV Unit1").department(deptA).build();

        admin = UserAccount.builder().id(1L).username("admin").role(UserRole.ADMIN).enabled(true).build();

        Employee headDeptEmp = Employee.builder().id(2L).fullName("Trưởng khoa").department(deptA).build();
        headDept = UserAccount.builder().id(2L).username("head").role(UserRole.HEAD_DEPARTMENT)
                .enabled(true).workUnitScoped(false).build();
        lenient().when(employeeLinkService.findLinkedEmployee(headDept)).thenReturn(Optional.of(headDeptEmp));

        Employee headUnit1Emp = Employee.builder().id(3L).fullName("Trưởng BP1").department(deptA).build();
        headUnit1 = UserAccount.builder().id(3L).username("unit1").role(UserRole.HEAD_DEPARTMENT)
                .enabled(true).workUnitScoped(true).build();
        lenient().when(employeeLinkService.findLinkedEmployee(headUnit1)).thenReturn(Optional.of(headUnit1Emp));
        lenient().when(employeeWorkforceDetailsRepository.findByEmployee(headUnit1Emp))
                .thenReturn(Optional.of(EmployeeWorkforceDetails.builder()
                        .employee(headUnit1Emp).workUnitDetail("Bộ phận 1").build()));

        Employee headUnit2Emp = Employee.builder().id(4L).fullName("Trưởng BP2").department(deptA).build();
        headUnit2 = UserAccount.builder().id(4L).username("unit2").role(UserRole.HEAD_DEPARTMENT)
                .enabled(true).workUnitScoped(true).build();
        lenient().when(employeeLinkService.findLinkedEmployee(headUnit2)).thenReturn(Optional.of(headUnit2Emp));
        lenient().when(employeeWorkforceDetailsRepository.findByEmployee(headUnit2Emp))
                .thenReturn(Optional.of(EmployeeWorkforceDetails.builder()
                        .employee(headUnit2Emp).workUnitDetail("Bộ phận 2").build()));

        lenient().when(employeeWorkforceDetailsRepository.findByEmployee(staffInUnit1))
                .thenReturn(Optional.of(EmployeeWorkforceDetails.builder()
                        .employee(staffInUnit1).workUnitDetail("Bộ phận 1").build()));
    }

    @Test
    void adminAlwaysReceives() {
        assertTrue(employeeService.shouldReceiveHeadPendingNotification(admin, staffInUnit1));
    }

    @Test
    void departmentHeadReceivesSameDepartmentOnly() {
        assertTrue(employeeService.shouldReceiveHeadPendingNotification(headDept, staffInUnit1));
        Employee otherDept = Employee.builder().id(99L).fullName("NV B").department(deptB).build();
        assertFalse(employeeService.shouldReceiveHeadPendingNotification(headDept, otherDept));
    }

    @Test
    void workUnitHeadReceivesOnlyOwnUnit() {
        assertTrue(employeeService.shouldReceiveHeadPendingNotification(headUnit1, staffInUnit1));
        assertFalse(employeeService.shouldReceiveHeadPendingNotification(headUnit2, staffInUnit1));
    }
}
