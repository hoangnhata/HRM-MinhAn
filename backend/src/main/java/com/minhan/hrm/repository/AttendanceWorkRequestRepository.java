package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AttendanceRequestStatus;
import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.AttendanceWorkRequest;
import com.minhan.hrm.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;

public interface AttendanceWorkRequestRepository extends JpaRepository<AttendanceWorkRequest, Long> {

    List<AttendanceWorkRequest> findByEmployeeAndWorkDateBetweenOrderByWorkDateDescCreatedAtDesc(
            Employee employee, LocalDate from, LocalDate to);

    List<AttendanceWorkRequest> findByEmployeeIdOrderByCreatedAtDesc(Long employeeId);

    List<AttendanceWorkRequest> findByStatusInOrderByCreatedAtAsc(Collection<AttendanceRequestStatus> statuses);

    List<AttendanceWorkRequest> findByStatusInOrderByUpdatedAtDesc(Collection<AttendanceRequestStatus> statuses);

    List<AttendanceWorkRequest> findByEmployeeIdAndWorkDateAndRequestType(
            Long employeeId, LocalDate workDate, AttendanceRequestType requestType);

    List<AttendanceWorkRequest> findByEmployeeIdAndWorkDateBetween(
            Long employeeId, LocalDate from, LocalDate to);

    long countByEmployeeIdAndRequestTypeAndStatusInAndWorkDateBetween(
            Long employeeId,
            AttendanceRequestType requestType,
            Collection<AttendanceRequestStatus> statuses,
            LocalDate from,
            LocalDate to);

    /**
     * Đơn đã duyệt có khoảng ngày giao với [from, to] (endDate null = chỉ workDate).
     */
    @Query("""
            SELECT r FROM AttendanceWorkRequest r
            JOIN FETCH r.employee
            WHERE r.status IN :statuses
              AND r.workDate <= :to
              AND COALESCE(r.endDate, r.workDate) >= :from
            ORDER BY r.workDate ASC, r.id ASC
            """)
    List<AttendanceWorkRequest> findApprovedOverlapping(
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("statuses") Collection<AttendanceRequestStatus> statuses);

    @Query("""
            SELECT r FROM AttendanceWorkRequest r
            JOIN FETCH r.employee e
            WHERE r.status IN :statuses
              AND e.id IN :employeeIds
              AND r.workDate <= :to
              AND COALESCE(r.endDate, r.workDate) >= :from
            ORDER BY r.workDate ASC, r.id ASC
            """)
    List<AttendanceWorkRequest> findApprovedOverlappingForEmployees(
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("employeeIds") Collection<Long> employeeIds,
            @Param("statuses") Collection<AttendanceRequestStatus> statuses);

    void deleteByEmployee_Id(Long employeeId);
}
