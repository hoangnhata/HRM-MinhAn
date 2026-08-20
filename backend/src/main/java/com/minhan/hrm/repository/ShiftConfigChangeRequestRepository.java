package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.ShiftConfigChangeRequest;
import com.minhan.hrm.entity.ShiftConfigChangeRequestStatus;
import com.minhan.hrm.entity.ShiftConfigChangeSeason;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface ShiftConfigChangeRequestRepository extends JpaRepository<ShiftConfigChangeRequest, Long> {

    @Query("""
            SELECT COUNT(r) > 0 FROM ShiftConfigChangeRequest r
            WHERE r.employee = :employee
              AND r.status = :status
              AND (
                   r.season = :season
                OR r.season = com.minhan.hrm.entity.ShiftConfigChangeSeason.BOTH
                OR (:season = com.minhan.hrm.entity.ShiftConfigChangeSeason.BOTH
                    AND r.season IN (
                        com.minhan.hrm.entity.ShiftConfigChangeSeason.SUMMER,
                        com.minhan.hrm.entity.ShiftConfigChangeSeason.WINTER
                    ))
              )
            """)
    boolean existsConflictingPending(
            @Param("employee") Employee employee,
            @Param("season") ShiftConfigChangeSeason season,
            @Param("status") ShiftConfigChangeRequestStatus status);

    @Query("""
            SELECT r FROM ShiftConfigChangeRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            WHERE r.status = :status
            ORDER BY r.createdAt ASC
            """)
    List<ShiftConfigChangeRequest> findPendingWithDetails(@Param("status") ShiftConfigChangeRequestStatus status);

    @Query("""
            SELECT r FROM ShiftConfigChangeRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.hrReviewer
            WHERE r.status <> com.minhan.hrm.entity.ShiftConfigChangeRequestStatus.PENDING_HR
            ORDER BY r.createdAt DESC, r.id DESC
            """)
    List<ShiftConfigChangeRequest> findHistoryWithDetails();

    List<ShiftConfigChangeRequest> findByRequestedBy_IdOrderByCreatedAtDesc(Long userId);

    List<ShiftConfigChangeRequest> findByEmployee_IdOrderByCreatedAtDesc(Long employeeId);

    @Query("""
            SELECT r FROM ShiftConfigChangeRequest r
            JOIN FETCH r.employee e
            JOIN FETCH r.requestedBy
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.hrReviewer
            WHERE r.id = :id
            """)
    Optional<ShiftConfigChangeRequest> findByIdWithDetails(@Param("id") Long id);
}
