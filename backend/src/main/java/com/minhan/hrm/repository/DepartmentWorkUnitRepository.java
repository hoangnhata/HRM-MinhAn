package com.minhan.hrm.repository;

import com.minhan.hrm.entity.DepartmentWorkUnit;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DepartmentWorkUnitRepository extends JpaRepository<DepartmentWorkUnit, Long> {

    List<DepartmentWorkUnit> findByDepartment_IdOrderByNameAsc(Long departmentId);

    Optional<DepartmentWorkUnit> findFirstByDepartment_IdAndNameIgnoreCaseOrderByIdAsc(
            Long departmentId, String name);

    boolean existsByDepartment_IdAndNameIgnoreCase(Long departmentId, String name);

    long countByDepartment_Id(Long departmentId);
}
