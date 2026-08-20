package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.MainDutyAuthorizationRequest;
import com.minhan.hrm.entity.MainDutyAuthorizationStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface MainDutyAuthorizationRequestRepository extends JpaRepository<MainDutyAuthorizationRequest, Long> {

    boolean existsByEmployeeAndStatusIn(Employee employee, Collection<MainDutyAuthorizationStatus> statuses);

    @Query("""
            SELECT r FROM MainDutyAuthorizationRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            WHERE r.status = :status
            ORDER BY r.createdAt ASC
            """)
    List<MainDutyAuthorizationRequest> findPendingWithDetails(@Param("status") MainDutyAuthorizationStatus status);

    List<MainDutyAuthorizationRequest> findByEmployeeIdOrderByCreatedAtDesc(Long employeeId);

    List<MainDutyAuthorizationRequest> findByRequestedBy_IdOrderByCreatedAtDesc(Long userId);

    @Query("""
            SELECT r FROM MainDutyAuthorizationRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.headReviewer
            LEFT JOIN FETCH r.nursingHeadReviewer
            LEFT JOIN FETCH r.hrReviewer
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.status NOT IN (
                com.minhan.hrm.entity.MainDutyAuthorizationStatus.PENDING_HEAD,
                com.minhan.hrm.entity.MainDutyAuthorizationStatus.PENDING_NURSING_HEAD,
                com.minhan.hrm.entity.MainDutyAuthorizationStatus.PENDING_HR,
                com.minhan.hrm.entity.MainDutyAuthorizationStatus.PENDING_DIRECTOR
            )
            ORDER BY r.createdAt DESC, r.id DESC
            """)
    List<MainDutyAuthorizationRequest> findReviewHistoryWithDetails();

    @Query("""
            SELECT r FROM MainDutyAuthorizationRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.headReviewer
            LEFT JOIN FETCH r.nursingHeadReviewer
            LEFT JOIN FETCH r.hrReviewer
            LEFT JOIN FETCH r.directorReviewer
            WHERE r.id = :id
            """)
    Optional<MainDutyAuthorizationRequest> findByIdWithDetails(@Param("id") Long id);
}
