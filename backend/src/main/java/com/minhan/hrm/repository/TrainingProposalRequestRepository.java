package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.TrainingProposalRequest;
import com.minhan.hrm.entity.TrainingProposalStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface TrainingProposalRequestRepository extends JpaRepository<TrainingProposalRequest, Long> {

    boolean existsByEmployeeAndStatusIn(Employee employee, Collection<TrainingProposalStatus> statuses);

    @Query("""
            SELECT r FROM TrainingProposalRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            WHERE r.status = :status
            ORDER BY r.createdAt ASC
            """)
    List<TrainingProposalRequest> findPendingWithDetails(@Param("status") TrainingProposalStatus status);

    List<TrainingProposalRequest> findByEmployeeIdOrderByCreatedAtDesc(Long employeeId);

    List<TrainingProposalRequest> findByRequestedBy_IdOrderByCreatedAtDesc(Long userId);

    @Query("""
            SELECT r FROM TrainingProposalRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.hrReviewer
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.status NOT IN (
                com.minhan.hrm.entity.TrainingProposalStatus.PENDING_HR,
                com.minhan.hrm.entity.TrainingProposalStatus.PENDING_DIRECTOR
            )
            ORDER BY r.createdAt DESC, r.id DESC
            """)
    List<TrainingProposalRequest> findReviewHistoryWithDetails();

    @Query("""
            SELECT r FROM TrainingProposalRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.hrReviewer
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.id = :id
            """)
    Optional<TrainingProposalRequest> findByIdWithDetails(@Param("id") Long id);

    @Query("""
            SELECT r FROM TrainingProposalRequest r
            JOIN FETCH r.employee e
            LEFT JOIN FETCH e.user
            JOIN FETCH r.requestedBy
            WHERE r.status = com.minhan.hrm.entity.TrainingProposalStatus.APPROVED
            """)
    List<TrainingProposalRequest> findApprovedWithEmployee();
}
