package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Position;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PositionRepository extends JpaRepository<Position, Long> {

    Optional<Position> findByCode(String code);

    Optional<Position> findByTitleIgnoreCase(String title);

    boolean existsByCode(String code);
}
