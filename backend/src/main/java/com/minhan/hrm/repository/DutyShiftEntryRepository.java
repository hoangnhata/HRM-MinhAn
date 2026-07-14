package com.minhan.hrm.repository;

import com.minhan.hrm.entity.DutyShiftEntry;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface DutyShiftEntryRepository extends JpaRepository<DutyShiftEntry, Long> {

    List<DutyShiftEntry> findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(
            Employee employee, LocalDate from, LocalDate to);

    Optional<DutyShiftEntry> findByEmployeeAndWorkDate(Employee employee, LocalDate workDate);

    void deleteByEmployee_Id(Long employeeId);

    @Modifying
    @Query("UPDATE DutyShiftEntry d SET d.enteredBy = NULL WHERE d.enteredBy = :user")
    void clearEnteredBy(@Param("user") UserAccount user);
}
