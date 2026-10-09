package com.minhan.hrm.service;

import com.minhan.hrm.entity.ContinuousShiftKind;
import com.minhan.hrm.entity.ContinuousShiftType;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeContinuousShiftDay;
import com.minhan.hrm.repository.ContinuousShiftTypeRepository;
import com.minhan.hrm.repository.EmployeeContinuousShiftDayRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ContinuousShiftServiceTwoPunchDayTest {

    private EmployeeContinuousShiftDayRepository dayRepository;
    private ContinuousShiftTypeRepository typeRepository;
    private EmployeeRepository employeeRepository;
    private ContinuousShiftService service;

    @BeforeEach
    void setUp() {
        dayRepository = mock(EmployeeContinuousShiftDayRepository.class);
        typeRepository = mock(ContinuousShiftTypeRepository.class);
        employeeRepository = mock(EmployeeRepository.class);
        service = new ContinuousShiftService(dayRepository, typeRepository, employeeRepository);
    }

    @Test
    void twoPunchAccountKeepsTwoPunchOnUnassignedDay() {
        when(employeeRepository.findById(9L)).thenReturn(Optional.of(
                Employee.builder().id(9L).continuousShift(true).build()));
        LocalDate date = LocalDate.of(2026, 9, 14);
        when(dayRepository.findById(new EmployeeContinuousShiftDay.Pk(9L, date)))
                .thenReturn(Optional.empty());

        assertTrue(service.isTwoPunchAttendance(9L));
        assertTrue(service.isTwoPunchAttendance(9L, date));
    }

    @Test
    void twoPunchAccountUsesFourPunchesOnSplitAssignedDay() {
        when(employeeRepository.findById(9L)).thenReturn(Optional.of(
                Employee.builder().id(9L).continuousShift(true).build()));
        LocalDate date = LocalDate.of(2026, 9, 13);
        when(dayRepository.findById(new EmployeeContinuousShiftDay.Pk(9L, date)))
                .thenReturn(Optional.of(EmployeeContinuousShiftDay.builder()
                        .employeeId(9L)
                        .workDate(date)
                        .shiftTypeId(3L)
                        .build()));
        when(typeRepository.findById(3L)).thenReturn(Optional.of(ContinuousShiftType.builder()
                .id(3L)
                .name("Ca SC lãnh đạo")
                .kind(ContinuousShiftKind.SPLIT)
                .build()));

        assertTrue(service.isTwoPunchAttendance(9L));
        assertTrue(service.isSplitDay(9L, date));
        assertFalse(service.isTwoPunchAttendance(9L, date));
    }
}
