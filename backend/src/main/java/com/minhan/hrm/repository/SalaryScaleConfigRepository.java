package com.minhan.hrm.repository;

import com.minhan.hrm.entity.SalaryScaleConfig;
import com.minhan.hrm.entity.SalaryScaleType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface SalaryScaleConfigRepository extends JpaRepository<SalaryScaleConfig, Long> {

    Optional<SalaryScaleConfig> findByScaleType(SalaryScaleType scaleType);
}
