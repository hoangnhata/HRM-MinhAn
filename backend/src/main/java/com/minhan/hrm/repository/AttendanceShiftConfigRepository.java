package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AttendanceShiftConfig;
import com.minhan.hrm.entity.AttendanceShiftSeason;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AttendanceShiftConfigRepository extends JpaRepository<AttendanceShiftConfig, AttendanceShiftSeason> {
}
