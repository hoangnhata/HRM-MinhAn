package com.minhan.hrm.repository;

import com.minhan.hrm.entity.AttendanceRequestStatus;
import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.AttendanceWorkRequest;
import com.minhan.hrm.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;

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

    void deleteByEmployee_Id(Long employeeId);
}
