package com.minhan.hrm.repository;

import com.minhan.hrm.entity.EmployeeContinuousShiftDay;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;

public interface EmployeeContinuousShiftDayRepository
        extends JpaRepository<EmployeeContinuousShiftDay, EmployeeContinuousShiftDay.Pk> {

    boolean existsByEmployeeIdAndWorkDate(Long employeeId, LocalDate workDate);

    List<EmployeeContinuousShiftDay> findByEmployeeIdAndWorkDateBetween(
            Long employeeId, LocalDate from, LocalDate to);

    List<EmployeeContinuousShiftDay> findByEmployeeIdInAndWorkDateBetween(
            Collection<Long> employeeIds, LocalDate from, LocalDate to);

    void deleteByEmployeeIdAndWorkDateBetween(Long employeeId, LocalDate from, LocalDate to);
}
