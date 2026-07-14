package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AttendanceLatePenaltyTier;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AttendanceLatePenaltyTierRepository extends JpaRepository<AttendanceLatePenaltyTier, Integer> {

    List<AttendanceLatePenaltyTier> findAllByOrderBySortOrderAsc();
}
