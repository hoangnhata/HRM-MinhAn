package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.ProbationConversionRequest;
import com.minhan.hrm.entity.ProbationConversionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ProbationConversionRequestRepository extends JpaRepository<ProbationConversionRequest, Long> {

    boolean existsByEmployeeAndStatusIn(Employee employee, Collection<ProbationConversionStatus> statuses);

    @Query("""
            SELECT r FROM ProbationConversionRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            WHERE r.status = :status
            ORDER BY r.createdAt ASC
            """)
    List<ProbationConversionRequest> findPendingWithDetails(@Param("status") ProbationConversionStatus status);

    @Query("""
            SELECT r FROM ProbationConversionRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.user
            WHERE r.status = com.minhan.hrm.entity.ProbationConversionStatus.APPROVED
              AND r.officialDate <= :today
            ORDER BY r.officialDate ASC, r.id ASC
            """)
    List<ProbationConversionRequest> findDueToApply(@Param("today") LocalDate today);

    List<ProbationConversionRequest> findByEmployeeIdOrderByCreatedAtDesc(Long employeeId);

    List<ProbationConversionRequest> findByRequestedBy_IdOrderByCreatedAtDesc(Long userId);

    @Query("""
            SELECT r FROM ProbationConversionRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH r.hrReviewer
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.status NOT IN (
                com.minhan.hrm.entity.ProbationConversionStatus.PENDING_HR,
                com.minhan.hrm.entity.ProbationConversionStatus.PENDING_DIRECTOR
            )
            ORDER BY r.createdAt DESC, r.id DESC
            """)
    List<ProbationConversionRequest> findReviewHistoryWithDetails();

    @Query("""
            SELECT r FROM ProbationConversionRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.hrReviewer
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.id = :id
            """)
    Optional<ProbationConversionRequest> findByIdWithDetails(@Param("id") Long id);
}
