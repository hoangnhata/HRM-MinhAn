package com.minhan.hrm.service;

import com.minhan.hrm.dto.attendance.AttendanceRequest;
import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AttendanceService {

    private final AttendanceRecordRepository attendanceRecordRepository;
    private final EmployeeService employeeService;
    private final EmployeeRepository employeeRepository;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listRange(Long employeeId, LocalDate from, LocalDate to) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanViewAttendance(emp);
        return attendanceRecordRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to)
                .stream()
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    /**
     * ADMIN gửi thông báo cho nhân viên khi đã cập nhật bảng công một tháng (bảo mật: chỉ user đích nhận).
     */
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public void notifyEmployeeAboutMonth(Long employeeId, int year, int month) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        notificationService.notifyAttendancePeriod(emp.getUser(), emp, year, month);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public Map<String, Object> upsert(AttendanceRequest req) {
        Employee emp = employeeService.requireEmployeeEntity(req.getEmployeeId());
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, req.getWorkDate())
                .orElseGet(() -> AttendanceRecord.builder().employee(emp).workDate(req.getWorkDate()).build());
        rec.setCheckIn(req.getCheckIn());
        rec.setCheckOut(req.getCheckOut());
        rec.setStatus(req.getStatus());
        rec.setNote(req.getNote());
        rec = attendanceRecordRepository.save(rec);
        return toMap(rec);
    }

    private void assertCanViewAttendance(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() == UserRole.ADMIN) {
            return;
        }
        Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
        if (self == null || !self.getId().equals(target.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem bảng công");
        }
    }

    private Map<String, Object> toMap(AttendanceRecord r) {
        return Map.of(
                "id", r.getId(),
                "employeeId", r.getEmployee().getId(),
                "workDate", r.getWorkDate().toString(),
                "checkIn", r.getCheckIn() != null ? r.getCheckIn().toString() : "",
                "checkOut", r.getCheckOut() != null ? r.getCheckOut().toString() : "",
                "status", r.getStatus(),
                "note", r.getNote() != null ? r.getNote() : "");
    }
}
