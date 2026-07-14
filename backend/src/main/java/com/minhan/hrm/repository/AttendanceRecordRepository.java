package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface AttendanceRecordRepository extends JpaRepository<AttendanceRecord, Long> {

    List<AttendanceRecord> findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
            Employee employee, LocalDate start, LocalDate end);

    Optional<AttendanceRecord> findByEmployeeAndWorkDate(Employee employee, LocalDate workDate);

    @Query("SELECT a FROM AttendanceRecord a WHERE a.employee.id IN :employeeIds "
            + "AND a.workDate BETWEEN :from AND :to")
    List<AttendanceRecord> findByEmployeeIdInAndWorkDateBetween(
            @Param("employeeIds") Collection<Long> employeeIds,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    @Query("SELECT DISTINCT a FROM AttendanceRecord a JOIN FETCH a.employee "
            + "WHERE a.workDate BETWEEN :from AND :to")
    List<AttendanceRecord> findByWorkDateBetweenWithEmployee(
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    void deleteByEmployee_Id(Long employeeId);
}
