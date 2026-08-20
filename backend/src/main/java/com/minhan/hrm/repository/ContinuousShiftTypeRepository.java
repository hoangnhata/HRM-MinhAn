package com.minhan.hrm.repository;

import com.minhan.hrm.entity.ContinuousShiftType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ContinuousShiftTypeRepository extends JpaRepository<ContinuousShiftType, Long> {

    List<ContinuousShiftType> findByActiveTrueOrderByNameAsc();

    List<ContinuousShiftType> findAllByOrderByNameAsc();

    boolean existsByNameIgnoreCaseAndActiveTrue(String name);

    boolean existsByNameIgnoreCaseAndActiveTrueAndIdNot(String name, Long id);

    java.util.Optional<ContinuousShiftType> findFirstByNameIgnoreCase(String name);
}
