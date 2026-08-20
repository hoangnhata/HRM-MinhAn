package com.minhan.hrm.repository;

import com.minhan.hrm.entity.EmployeeYoungChildPeriod;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;

public interface EmployeeYoungChildPeriodRepository extends JpaRepository<EmployeeYoungChildPeriod, Long> {

    boolean existsByEmployeeIdAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
            Long employeeId, LocalDate date1, LocalDate date2);

    @Query("""
            SELECT p FROM EmployeeYoungChildPeriod p
            WHERE p.employeeId = :employeeId
              AND p.startDate <= :toDate
              AND p.endDate >= :fromDate
            ORDER BY p.startDate ASC
            """)
    List<EmployeeYoungChildPeriod> findOverlapping(
            @Param("employeeId") Long employeeId,
            @Param("fromDate") LocalDate fromDate,
            @Param("toDate") LocalDate toDate);

    @Query("""
            SELECT p FROM EmployeeYoungChildPeriod p
            WHERE p.employeeId IN :employeeIds
              AND p.startDate <= :toDate
              AND p.endDate >= :fromDate
            """)
    List<EmployeeYoungChildPeriod> findOverlappingForEmployees(
            @Param("employeeIds") Collection<Long> employeeIds,
            @Param("fromDate") LocalDate fromDate,
            @Param("toDate") LocalDate toDate);
}
