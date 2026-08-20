package com.minhan.hrm.config;

import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.DepartmentWorkUnitRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.PositionRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.boot.ApplicationArguments;
import org.springframework.data.domain.Sort;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DemoDataCleanupRunnerTest {

    @Mock private UserAccountRepository userAccountRepository;
    @Mock private EmployeeRepository employeeRepository;
    @Mock private DepartmentRepository departmentRepository;
    @Mock private DepartmentWorkUnitRepository workUnitRepository;
    @Mock private PositionRepository positionRepository;
    @Mock private EntityManager entityManager;

    @InjectMocks private DemoDataCleanupRunner runner;

    @Test
    void removesDemoAccountsAndDepartmentButKeepsAdmin() {
        ReflectionTestUtils.setField(runner, "entityManager", entityManager);

        UserAccount admin = UserAccount.builder()
                .id(1L).username("admin").role(UserRole.ADMIN).build();
        UserAccount demoUser = UserAccount.builder()
                .id(10L).username(DemoDataCleanupRunner.DEMO_USERNAME).role(UserRole.EMPLOYEE).build();
        UserAccount internUser = UserAccount.builder()
                .id(11L).username(DemoDataCleanupRunner.DEMO_INTERN_USERNAME).role(UserRole.EMPLOYEE).build();
        Department department = Department.builder()
                .id(5L).code(DemoDataCleanupRunner.DEMO_DEPARTMENT_CODE).name("KHOA KHÁM BỆNH (DEMO)").build();
        Employee demoEmployee = Employee.builder()
                .id(20L)
                .employeeCode(DemoDataCleanupRunner.DEMO_EMPLOYEE_CODE)
                .user(demoUser)
                .department(department)
                .build();
        Employee internEmployee = Employee.builder()
                .id(21L)
                .employeeCode(DemoDataCleanupRunner.DEMO_INTERN_EMPLOYEE_CODE)
                .user(internUser)
                .department(department)
                .build();

        when(employeeRepository.findByEmployeeCode(DemoDataCleanupRunner.DEMO_EMPLOYEE_CODE))
                .thenReturn(Optional.of(demoEmployee));
        when(employeeRepository.findByEmployeeCode(DemoDataCleanupRunner.DEMO_INTERN_EMPLOYEE_CODE))
                .thenReturn(Optional.of(internEmployee));
        when(userAccountRepository.findByUsername(DemoDataCleanupRunner.DEMO_USERNAME))
                .thenReturn(Optional.of(demoUser));
        when(userAccountRepository.findByUsername(DemoDataCleanupRunner.DEMO_INTERN_USERNAME))
                .thenReturn(Optional.of(internUser));
        when(userAccountRepository.findByUsername("admin")).thenReturn(Optional.of(admin));
        when(employeeRepository.findByUser(demoUser)).thenReturn(Optional.empty());
        when(employeeRepository.findByUser(internUser)).thenReturn(Optional.empty());
        when(departmentRepository.findByCode(DemoDataCleanupRunner.DEMO_DEPARTMENT_CODE))
                .thenReturn(Optional.of(department));
        when(employeeRepository.findByDepartment_Id(eq(5L), any(Sort.class)))
                .thenReturn(List.of(demoEmployee, internEmployee));
        when(employeeRepository.findById(20L)).thenReturn(Optional.of(demoEmployee));
        when(employeeRepository.findById(21L)).thenReturn(Optional.of(internEmployee));
        when(userAccountRepository.findById(10L)).thenReturn(Optional.of(demoUser));
        when(userAccountRepository.findById(11L)).thenReturn(Optional.of(internUser));
        when(employeeRepository.countByDepartment_Id(5L)).thenReturn(0L);
        when(workUnitRepository.findByDepartment_IdOrderByNameAsc(5L)).thenReturn(List.of());
        when(positionRepository.findByCode(anyString())).thenReturn(Optional.empty());
        when(entityManager.createNativeQuery(anyString())).thenAnswer(invocation -> {
            jakarta.persistence.Query query = mock(jakarta.persistence.Query.class);
            when(query.setParameter(anyString(), any())).thenReturn(query);
            when(query.executeUpdate()).thenReturn(0);
            return query;
        });

        runner.run(mock(ApplicationArguments.class));

        verify(employeeRepository).delete(demoEmployee);
        verify(employeeRepository).delete(internEmployee);
        verify(userAccountRepository).delete(demoUser);
        verify(userAccountRepository).delete(internUser);
        verify(departmentRepository).delete(department);
        verify(userAccountRepository, never()).delete(admin);
    }
}
