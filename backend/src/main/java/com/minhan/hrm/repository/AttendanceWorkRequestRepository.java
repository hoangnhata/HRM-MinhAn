package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AttendanceRequestStatus;
import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.AttendanceWorkRequest;
import com.minhan.hrm.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
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

    /**
     * Đơn của một nhân viên, nạp sẵn mọi quan hệ mà {@code toMap} cần
     * (phòng ban, chức danh, bốn người duyệt và nhân viên gắn với họ) để
     * danh sách N dòng không thành N×8 truy vấn lazy.
     */
    @Query("""
            SELECT r FROM AttendanceWorkRequest r
            JOIN FETCH r.employee e
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.headReviewer hrv
            LEFT JOIN FETCH hrv.employee
            LEFT JOIN FETCH r.nursingHeadReviewer nrv
            LEFT JOIN FETCH nrv.employee
            LEFT JOIN FETCH r.hrReviewer rrv
            LEFT JOIN FETCH rrv.employee
            LEFT JOIN FETCH r.directorReviewer drv
            LEFT JOIN FETCH drv.employee
            WHERE e.id = :employeeId
            ORDER BY r.createdAt DESC
            """)
    List<AttendanceWorkRequest> findMineWithDetails(@Param("employeeId") Long employeeId);

    /** Hàng đợi chờ duyệt theo trạng thái, nạp sẵn quan hệ như {@link #findMineWithDetails}. */
    @Query("""
            SELECT r FROM AttendanceWorkRequest r
            JOIN FETCH r.employee e
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.headReviewer hrv
            LEFT JOIN FETCH hrv.employee
            LEFT JOIN FETCH r.nursingHeadReviewer nrv
            LEFT JOIN FETCH nrv.employee
            LEFT JOIN FETCH r.hrReviewer rrv
            LEFT JOIN FETCH rrv.employee
            LEFT JOIN FETCH r.directorReviewer drv
            LEFT JOIN FETCH drv.employee
            WHERE r.status IN :statuses
            ORDER BY r.createdAt ASC
            """)
    List<AttendanceWorkRequest> findPendingWithDetails(
            @Param("statuses") Collection<AttendanceRequestStatus> statuses);

    /**
     * Lịch sử duyệt trong cửa sổ thời gian tạo đơn [from, to). Luôn truyền
     * mốc cụ thể: MySQL không suy được kiểu cho tham số Instant null.
     */
    @Query("""
            SELECT r FROM AttendanceWorkRequest r
            JOIN FETCH r.employee e
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH r.headReviewer hrv
            LEFT JOIN FETCH hrv.employee
            LEFT JOIN FETCH r.nursingHeadReviewer nrv
            LEFT JOIN FETCH nrv.employee
            LEFT JOIN FETCH r.hrReviewer rrv
            LEFT JOIN FETCH rrv.employee
            LEFT JOIN FETCH r.directorReviewer drv
            LEFT JOIN FETCH drv.employee
            WHERE r.status IN :statuses
              AND r.createdAt >= :from
              AND r.createdAt < :to
            ORDER BY r.updatedAt DESC
            """)
    List<AttendanceWorkRequest> findHistoryWithDetails(
            @Param("statuses") Collection<AttendanceRequestStatus> statuses,
            @Param("from") Instant from,
            @Param("to") Instant to);

    /**
     * Đơn điều động theo ngày làm việc trong khoảng [from, to], bỏ đơn đã thu hồi.
     */
    @Query("""
            SELECT r FROM AttendanceWorkRequest r
            JOIN FETCH r.employee e
            JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            WHERE r.requestType = com.minhan.hrm.entity.AttendanceRequestType.DEPLOYMENT
              AND r.workDate >= :from
              AND r.workDate <= :to
              AND r.status <> com.minhan.hrm.entity.AttendanceRequestStatus.WITHDRAWN
            ORDER BY r.workDate ASC, e.department.name ASC, e.fullName ASC, r.id ASC
            """)
    List<AttendanceWorkRequest> findDeploymentsByWorkDateBetween(
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);
}
