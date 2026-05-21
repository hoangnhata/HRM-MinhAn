package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface EmployeeWorkforceDetailsRepository extends JpaRepository<EmployeeWorkforceDetails, Long> {

    Optional<EmployeeWorkforceDetails> findByEmployee(Employee employee);
}
