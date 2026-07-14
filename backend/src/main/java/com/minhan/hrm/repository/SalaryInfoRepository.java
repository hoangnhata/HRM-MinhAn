package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.SalaryInfo;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface SalaryInfoRepository extends JpaRepository<SalaryInfo, Long> {

    Optional<SalaryInfo> findByEmployee(Employee employee);

    List<SalaryInfo> findByNextReviewDateBetween(LocalDate from, LocalDate to);

    long countByNextReviewDateBetween(LocalDate from, LocalDate to);

    void deleteByEmployee_Id(Long employeeId);
}
