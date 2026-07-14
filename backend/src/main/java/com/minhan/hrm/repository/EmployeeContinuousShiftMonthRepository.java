package com.minhan.hrm.repository;

import com.minhan.hrm.entity.EmployeeContinuousShiftMonth;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;

public interface EmployeeContinuousShiftMonthRepository
        extends JpaRepository<EmployeeContinuousShiftMonth, EmployeeContinuousShiftMonth.Pk> {

    boolean existsByEmployeeIdAndPeriodYearAndPeriodMonth(Long employeeId, int periodYear, int periodMonth);

    List<EmployeeContinuousShiftMonth> findByEmployeeIdIn(Collection<Long> employeeIds);
}
