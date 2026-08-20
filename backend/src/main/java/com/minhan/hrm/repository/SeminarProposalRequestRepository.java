package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.SeminarProposalRequest;
import com.minhan.hrm.entity.SeminarProposalStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.Set;

public interface SeminarProposalRequestRepository extends JpaRepository<SeminarProposalRequest, Long> {

    boolean existsByEmployeeAndStatusIn(Employee employee, Collection<SeminarProposalStatus> statuses);

    @Query("""
            SELECT r FROM SeminarProposalRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            WHERE r.status = :status
            ORDER BY r.createdAt ASC
            """)
    List<SeminarProposalRequest> findPendingWithDetails(@Param("status") SeminarProposalStatus status);

    List<SeminarProposalRequest> findByEmployeeIdOrderByCreatedAtDesc(Long employeeId);

    List<SeminarProposalRequest> findByRequestedBy_IdOrderByCreatedAtDesc(Long userId);

    @Query("""
            SELECT r FROM SeminarProposalRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.hrReviewer
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.status NOT IN (
                com.minhan.hrm.entity.SeminarProposalStatus.PENDING_HR,
                com.minhan.hrm.entity.SeminarProposalStatus.PENDING_DIRECTOR
            )
            ORDER BY r.createdAt DESC, r.id DESC
            """)
    List<SeminarProposalRequest> findReviewHistoryWithDetails();

    @Query("""
            SELECT r FROM SeminarProposalRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.hrReviewer
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.id = :id
            """)
    Optional<SeminarProposalRequest> findByIdWithDetails(@Param("id") Long id);

    @Query("""
            SELECT r FROM SeminarProposalRequest r
            JOIN FETCH r.employee e
            LEFT JOIN FETCH e.user
            JOIN FETCH r.requestedBy
            WHERE r.status = com.minhan.hrm.entity.SeminarProposalStatus.APPROVED
              AND r.endDate < :today
            """)
    List<SeminarProposalRequest> findApprovedEndedBefore(@Param("today") LocalDate today);

    @Query("""
            SELECT r FROM SeminarProposalRequest r
            WHERE r.employee.id = :employeeId
              AND r.status IN (
                com.minhan.hrm.entity.SeminarProposalStatus.APPROVED,
                com.minhan.hrm.entity.SeminarProposalStatus.COMPLETED
              )
              AND r.supportAmount IS NOT NULL
              AND TRIM(r.supportAmount) <> ''
              AND r.startDate <= :to
              AND r.endDate >= :from
            ORDER BY r.startDate ASC, r.id ASC
            """)
    List<SeminarProposalRequest> findApprovedWithSupportInPeriod(
            @Param("employeeId") Long employeeId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    @Query("""
            SELECT r FROM SeminarProposalRequest r
            WHERE r.employee.id = :employeeId
              AND r.status IN :statuses
              AND r.startDate <= :to
              AND r.endDate >= :from
            ORDER BY r.startDate ASC, r.id ASC
            """)
    List<SeminarProposalRequest> findOverlappingForEmployee(
            @Param("employeeId") Long employeeId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("statuses") Set<SeminarProposalStatus> statuses);
}
