package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Department;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface DepartmentRepository extends JpaRepository<Department, Long> {

    Optional<Department> findByCode(String code);

    Optional<Department> findByNameIgnoreCase(String name);

    boolean existsByCode(String code);
}
