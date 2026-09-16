package com.minhan.hrm.repository;

import com.minhan.hrm.entity.NursingDailyReport;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface NursingDailyReportRepository extends JpaRepository<NursingDailyReport, Long> {

    Optional<NursingDailyReport> findByDepartment_IdAndReportDate(Long departmentId, LocalDate reportDate);

    boolean existsByDepartment_IdAndReportDate(Long departmentId, LocalDate reportDate);

    List<NursingDailyReport> findByReportDateOrderByDepartment_NameAsc(LocalDate reportDate);

    List<NursingDailyReport> findByReportDateAndDepartment_IdInOrderByDepartment_NameAsc(
            LocalDate reportDate, Iterable<Long> departmentIds);

    List<NursingDailyReport> findByDepartment_IdInAndReportDateBetweenOrderByReportDateAscDepartment_NameAsc(
            Iterable<Long> departmentIds, LocalDate from, LocalDate to);
}
