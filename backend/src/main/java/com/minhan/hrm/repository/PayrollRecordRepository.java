package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.PayrollRecord;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PayrollRecordRepository extends JpaRepository<PayrollRecord, Long> {

    List<PayrollRecord> findByEmployeeOrderByPeriodYearDescPeriodMonthDesc(Employee employee);

    Optional<PayrollRecord> findByEmployeeAndPeriodYearAndPeriodMonth(
            Employee employee, int year, int month);
}
