package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface EmployeeWorkforceDetailsRepository extends JpaRepository<EmployeeWorkforceDetails, Long> {

    Optional<EmployeeWorkforceDetails> findByEmployee(Employee employee);

    List<EmployeeWorkforceDetails> findByEmployeeIn(List<Employee> employees);

    Optional<EmployeeWorkforceDetails> findByAttendanceCode(String attendanceCode);

    List<EmployeeWorkforceDetails> findByAttendanceCodeIsNotNull();

    @Query("""
            SELECT COUNT(w) FROM EmployeeWorkforceDetails w
            JOIN w.employee e
            WHERE e.status IN (com.minhan.hrm.entity.EmployeeStatus.ACTIVE, com.minhan.hrm.entity.EmployeeStatus.ON_LEAVE)
            AND (
                LOWER(w.insuranceParticipation) LIKE '%thai sản%'
                OR LOWER(w.insuranceParticipation) LIKE '%thai san%'
            )
            """)
    long countMaternityLeaveOfficial();
}
