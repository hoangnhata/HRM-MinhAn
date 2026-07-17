package com.minhan.hrm.repository;

import com.minhan.hrm.entity.DepartmentTransferRequest;
import com.minhan.hrm.entity.DepartmentTransferStatus;
import com.minhan.hrm.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;

public interface DepartmentTransferRequestRepository extends JpaRepository<DepartmentTransferRequest, Long> {

    boolean existsByEmployeeAndStatusIn(Employee employee, Collection<DepartmentTransferStatus> statuses);

    List<DepartmentTransferRequest> findByStatusOrderByCreatedAtAsc(DepartmentTransferStatus status);

    @Query("""
            SELECT r FROM DepartmentTransferRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.fromDepartment
            JOIN FETCH r.toDepartment
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH r.toPosition
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            WHERE r.status = :status
            ORDER BY r.createdAt ASC
            """)
    List<DepartmentTransferRequest> findPendingWithDetails(@Param("status") DepartmentTransferStatus status);

    @Query("""
            SELECT r from DepartmentTransferRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.fromDepartment
            JOIN FETCH r.toDepartment
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH r.toPosition
            LEFT JOIN FETCH e.user
            WHERE r.status = com.minhan.hrm.entity.DepartmentTransferStatus.APPROVED
              AND r.effectiveDate <= :today
            ORDER BY r.effectiveDate ASC, r.id ASC
            """)
    List<DepartmentTransferRequest> findDueToApply(@Param("today") LocalDate today);

    List<DepartmentTransferRequest> findByEmployeeIdOrderByCreatedAtDesc(Long employeeId);

    @Query("""
            SELECT r FROM DepartmentTransferRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.fromDepartment
            JOIN FETCH r.toDepartment
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH r.toPosition
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.status <> com.minhan.hrm.entity.DepartmentTransferStatus.PENDING_DIRECTOR
            ORDER BY r.createdAt DESC, r.id DESC
            """)
    List<DepartmentTransferRequest> findReviewHistoryWithDetails();

    @Query("""
            SELECT r FROM DepartmentTransferRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.fromDepartment
            JOIN FETCH r.toDepartment
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH r.toPosition
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.id = :id
            """)
    java.util.Optional<DepartmentTransferRequest> findByIdWithDetails(@Param("id") Long id);
}
