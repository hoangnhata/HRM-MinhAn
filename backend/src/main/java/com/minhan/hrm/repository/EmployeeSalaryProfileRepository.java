package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeSalaryProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface EmployeeSalaryProfileRepository extends JpaRepository<EmployeeSalaryProfile, Long> {

    Optional<EmployeeSalaryProfile> findByEmployee(Employee employee);

    Optional<EmployeeSalaryProfile> findByEmployeeId(Long employeeId);

    void deleteByEmployee_Id(Long employeeId);
}
