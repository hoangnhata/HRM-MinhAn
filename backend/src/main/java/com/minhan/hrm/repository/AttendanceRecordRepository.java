package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface AttendanceRecordRepository extends JpaRepository<AttendanceRecord, Long> {

    List<AttendanceRecord> findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
            Employee employee, LocalDate start, LocalDate end);

    Optional<AttendanceRecord> findByEmployeeAndWorkDate(Employee employee, LocalDate workDate);
}
