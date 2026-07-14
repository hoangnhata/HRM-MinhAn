package com.minhan.hrm.repository;

import com.minhan.hrm.entity.SalaryScaleDoctorEntry;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SalaryScaleDoctorEntryRepository extends JpaRepository<SalaryScaleDoctorEntry, Long> {

    List<SalaryScaleDoctorEntry> findAllByOrderBySortOrderAsc();
}
