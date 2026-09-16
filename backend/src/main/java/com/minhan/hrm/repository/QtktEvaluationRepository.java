package com.minhan.hrm.repository;

import com.minhan.hrm.entity.QtktEvaluation;
import com.minhan.hrm.entity.QtktEvaluationStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface QtktEvaluationRepository extends JpaRepository<QtktEvaluation, Long> {

    Optional<QtktEvaluation> findByEmployee_IdAndProcedureCodeAndEvalDateAndCheckContextCodeAndPatientCode(
            Long employeeId,
            String procedureCode,
            LocalDate evalDate,
            String checkContextCode,
            String patientCode);

    List<QtktEvaluation> findByDepartment_IdInAndEvalDateBetweenOrderByEvalDateDescProcedureNameAsc(
            Iterable<Long> departmentIds, LocalDate from, LocalDate to);

    @Query("""
            SELECT e FROM QtktEvaluation e
            WHERE e.department.id IN :deptIds
              AND e.evalDate BETWEEN :from AND :to
              AND (:status IS NULL OR e.status = :status)
              AND (:procedureCode IS NULL OR e.procedureCode = :procedureCode)
              AND (:departmentId IS NULL OR e.department.id = :departmentId)
            ORDER BY e.evalDate DESC, e.procedureName ASC, e.employee.fullName ASC
            """)
    List<QtktEvaluation> search(
            @Param("deptIds") Iterable<Long> deptIds,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("status") QtktEvaluationStatus status,
            @Param("procedureCode") String procedureCode,
            @Param("departmentId") Long departmentId);

    @Query("""
            SELECT e FROM QtktEvaluation e
            WHERE e.department.id IN :deptIds
              AND e.evalDate BETWEEN :from AND :to
              AND e.status = com.minhan.hrm.entity.QtktEvaluationStatus.SUBMITTED
              AND e.procedureCode IN :procedureCodes
              AND (:departmentId IS NULL OR e.department.id = :departmentId)
              AND (:employeeId IS NULL OR e.employee.id = :employeeId)
            ORDER BY e.evalDate DESC, e.procedureName ASC, e.employee.fullName ASC
            """)
    List<QtktEvaluation> findSubmittedForCompliance(
            @Param("deptIds") Iterable<Long> deptIds,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("procedureCodes") Collection<String> procedureCodes,
            @Param("departmentId") Long departmentId,
            @Param("employeeId") Long employeeId);
}
