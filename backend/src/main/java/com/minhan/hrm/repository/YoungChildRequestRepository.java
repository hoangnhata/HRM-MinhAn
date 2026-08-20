package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.YoungChildRequest;
import com.minhan.hrm.entity.YoungChildRequestStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface YoungChildRequestRepository extends JpaRepository<YoungChildRequest, Long> {

    @Query("""
            SELECT CASE WHEN COUNT(r) > 0 THEN true ELSE false END FROM YoungChildRequest r
            WHERE r.employee = :employee AND r.status = :status
              AND r.startDate <= :endDate AND r.endDate >= :startDate
            """)
    boolean existsOverlapping(
            @Param("employee") Employee employee,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate,
            @Param("status") YoungChildRequestStatus status);

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

    List<YoungChildRequest> findByEmployee_IdOrderByCreatedAtDesc(Long employeeId);

    @Query("""
            SELECT r FROM YoungChildRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH r.hrReviewer
            WHERE r.id = :id
            """)
    Optional<YoungChildRequest> findByIdWithDetails(@Param("id") Long id);

    @Query("""
            SELECT r FROM YoungChildRequest r
            WHERE r.employee.id = :employeeId AND r.status = :status
              AND r.startDate <= :toDate AND r.endDate >= :fromDate
            ORDER BY r.createdAt DESC
            """)
    List<YoungChildRequest> findPendingOverlapping(
            @Param("employeeId") Long employeeId,
            @Param("fromDate") LocalDate fromDate,
            @Param("toDate") LocalDate toDate,
            @Param("status") YoungChildRequestStatus status);
}
