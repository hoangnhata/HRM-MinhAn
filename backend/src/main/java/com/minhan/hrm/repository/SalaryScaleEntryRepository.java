package com.minhan.hrm.repository;

import com.minhan.hrm.entity.SalaryScaleEntry;
import com.minhan.hrm.entity.SalaryScaleType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SalaryScaleEntryRepository extends JpaRepository<SalaryScaleEntry, Long> {

    Optional<SalaryScaleEntry> findByScaleTypeAndQualificationAndGradeLevel(
            SalaryScaleType scaleType, String qualification, int gradeLevel);

    List<SalaryScaleEntry> findByScaleTypeOrderByQualificationAscGradeLevelAsc(SalaryScaleType scaleType);

    long countByScaleType(SalaryScaleType scaleType);
}
