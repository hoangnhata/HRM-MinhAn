package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AttendanceHolidayWorkDay;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface AttendanceHolidayWorkDayRepository extends JpaRepository<AttendanceHolidayWorkDay, LocalDate> {

    List<AttendanceHolidayWorkDay> findByWorkDateBetweenOrderByWorkDateAsc(LocalDate from, LocalDate to);

    boolean existsByWorkDate(LocalDate workDate);

    void deleteByWorkDateBetween(LocalDate from, LocalDate to);
}
