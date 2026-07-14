package com.minhan.hrm.repository;

import com.minhan.hrm.entity.EmployeeYoungChildMonth;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;

public interface EmployeeYoungChildMonthRepository
        extends JpaRepository<EmployeeYoungChildMonth, EmployeeYoungChildMonth.Pk> {

    boolean existsByEmployeeIdAndPeriodYearAndPeriodMonth(Long employeeId, int periodYear, int periodMonth);

    List<EmployeeYoungChildMonth> findByEmployeeIdIn(Collection<Long> employeeIds);
}
