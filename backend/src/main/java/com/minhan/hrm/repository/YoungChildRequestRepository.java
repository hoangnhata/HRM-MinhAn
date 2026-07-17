package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.YoungChildRequest;
import com.minhan.hrm.entity.YoungChildRequestStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface YoungChildRequestRepository extends JpaRepository<YoungChildRequest, Long> {

    boolean existsByEmployeeAndPeriodYearAndPeriodMonthAndStatus(
            Employee employee, int periodYear, int periodMonth, YoungChildRequestStatus status);

    @Query("""
            SELECT r FROM YoungChildRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            WHERE r.status = :status
            ORDER BY r.createdAt ASC
            """)
    List<YoungChildRequest> findPendingWithDetails(@Param("status") YoungChildRequestStatus status);

    @Query("""
            SELECT r FROM YoungChildRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH r.hrReviewer
            WHERE r.status <> com.minhan.hrm.entity.YoungChildRequestStatus.PENDING_HR
            ORDER BY r.createdAt DESC, r.id DESC
            """)
    List<YoungChildRequest> findHistoryWithDetails();

    List<YoungChildRequest> findByRequestedBy_IdOrderByCreatedAtDesc(Long userId);

    @Query("""
            SELECT r FROM YoungChildRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH r.hrReviewer
            WHERE r.id = :id
            """)
    Optional<YoungChildRequest> findByIdWithDetails(@Param("id") Long id);

    Optional<YoungChildRequest> findFirstByEmployee_IdAndPeriodYearAndPeriodMonthAndStatusOrderByCreatedAtDesc(
            Long employeeId, int periodYear, int periodMonth, YoungChildRequestStatus status);
}
