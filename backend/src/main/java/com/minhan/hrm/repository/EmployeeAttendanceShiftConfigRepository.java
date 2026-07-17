package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AttendanceShiftSeason;
import com.minhan.hrm.entity.EmployeeAttendanceShiftConfig;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface EmployeeAttendanceShiftConfigRepository
        extends JpaRepository<EmployeeAttendanceShiftConfig, Long> {

    Optional<EmployeeAttendanceShiftConfig> findByEmployee_IdAndSeason(
            Long employeeId, AttendanceShiftSeason season);

    List<EmployeeAttendanceShiftConfig> findByEmployee_Id(Long employeeId);
}
