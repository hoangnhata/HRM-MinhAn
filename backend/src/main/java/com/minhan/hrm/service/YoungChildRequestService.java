package com.minhan.hrm.service;

import com.minhan.hrm.dto.youngchild.YoungChildRequestCreateDto;
import com.minhan.hrm.dto.youngchild.YoungChildRequestReviewDto;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.repository.YoungChildRequestRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class YoungChildRequestService {

    private final YoungChildRequestRepository requestRepository;
    private final EmployeeRepository employeeRepository;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeService employeeService;
    private final YoungChildHoursService youngChildHoursService;
    private final AttendanceService attendanceService;
    private final NotificationService notificationService;

    @Transactional
    public Map<String, Object> create(YoungChildRequestCreateDto req) {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && actor.getRole() != UserRole.HEAD_DEPARTMENT
                && actor.getRole() != UserRole.HEAD_NURSING) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ Trưởng khoa/phòng hoặc Điều dưỡng trưởng được đề xuất chế độ nuôi con nhỏ");
        }
        Employee emp = employeeRepository.findById(req.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (emp.getStatus() == EmployeeStatus.TERMINATED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đề xuất cho nhân viên đã nghỉ việc");
        }

        boolean enabled = Boolean.TRUE.equals(req.getEnabled());
        int year = req.getYear();
        int month = req.getMonth();
        boolean currentlyOn = youngChildHoursService.isYoungChildMonth(emp.getId(), year, month);
        if (enabled == currentlyOn) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    enabled
                            ? "Nhân viên đã đang bật nuôi con nhỏ tháng này"
                            : "Nhân viên chưa bật nuôi con nhỏ tháng này");
        }
        if (requestRepository.existsByEmployeeAndPeriodYearAndPeriodMonthAndStatus(
                emp, year, month, YoungChildRequestStatus.PENDING_HR)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đã có đề xuất nuôi con nhỏ đang chờ HCNS duyệt cho tháng này");
        }

        YoungChildRequest row = YoungChildRequest.builder()
                .employee(emp)
                .periodYear(year)
                .periodMonth(month)
                .enabled(enabled)
                .reason(req.getReason() != null && !req.getReason().isBlank() ? req.getReason().trim() : null)
                .status(YoungChildRequestStatus.PENDING_HR)
                .requestedBy(actor)
                .build();
        row = requestRepository.save(row);
        notifyHrPending(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingHr() {
        ensureCanViewAsHr();
        return requestRepository.findPendingWithDetails(YoungChildRequestStatus.PENDING_HR).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listHistory() {
        ensureCanViewAsHr();
        return requestRepository.findHistoryWithDetails().stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listMine() {
        UserAccount actor = employeeService.currentUser();
        return requestRepository.findByRequestedBy_IdOrderByCreatedAtDesc(actor.getId()).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getById(Long id) {
        YoungChildRequest row = requestRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất nuôi con nhỏ"));
        ensureCanViewRequest(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getPendingForEmployeeMonth(Long employeeId, int year, int month) {
        return requestRepository
                .findFirstByEmployee_IdAndPeriodYearAndPeriodMonthAndStatusOrderByCreatedAtDesc(
                        employeeId, year, month, YoungChildRequestStatus.PENDING_HR)
                .map(this::toMap)
                .orElse(null);
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, YoungChildRequestReviewDto body) {
        UserAccount hr = ensureHrOrAdmin();
        YoungChildRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất nuôi con nhỏ"));
        if (row.getStatus() != YoungChildRequestStatus.PENDING_HR) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đề xuất không còn chờ HCNS duyệt");
        }
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setHrReviewer(hr);
        row.setHrReviewedAt(Instant.now());
        row.setHrComment(body.getComment() != null && !body.getComment().isBlank()
                ? body.getComment().trim() : null);

        if (!approved) {
            row.setStatus(YoungChildRequestStatus.REJECTED);
            requestRepository.save(row);
            notificationService.notifyYoungChildRequestResult(row, false);
            return toMap(row);
        }

        youngChildHoursService.setYoungChildMonth(
                row.getEmployee().getId(), row.getPeriodYear(), row.getPeriodMonth(), row.isEnabled());
        row.setStatus(YoungChildRequestStatus.APPROVED);
        requestRepository.save(row);

        int recalculated = 0;
        String recalculateWarning = null;
        try {
            recalculated = attendanceService.recalculateEmployeeMonth(
                    row.getEmployee().getId(), row.getPeriodYear(), row.getPeriodMonth());
        } catch (Exception e) {
            log.warn("Duyệt nuôi con nhỏ nhưng tính lại công thất bại — employee {} {}/{}",
                    row.getEmployee().getId(), row.getPeriodMonth(), row.getPeriodYear(), e);
            recalculateWarning = "Đã duyệt nhưng chưa tính lại được bảng công.";
        }

        notificationService.notifyYoungChildRequestResult(row, true);
        Map<String, Object> m = toMap(row);
        m.put("recalculated", recalculated);
        if (recalculateWarning != null) {
            m.put("recalculateWarning", recalculateWarning);
        }
        return m;
    }

    @Transactional
    public Map<String, Object> cancel(Long id) {
        UserAccount actor = employeeService.currentUser();
        YoungChildRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất nuôi con nhỏ"));
        boolean canCancel = actor.getRole() == UserRole.ADMIN
                || (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(actor.getId()));
        if (!canCancel) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền hủy đề xuất này");
        }
        if (row.getStatus() != YoungChildRequestStatus.PENDING_HR) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ hủy được đề xuất đang chờ duyệt");
        }
        row.setStatus(YoungChildRequestStatus.CANCELLED);
        requestRepository.save(row);
        return toMap(row);
    }

    private void notifyHrPending(YoungChildRequest row) {
        List<UserAccount> hrs = userAccountRepository.findByRoleIn(List.of(UserRole.HR, UserRole.ADMIN));
        for (UserAccount u : hrs) {
            if (!u.isEnabled()) {
                continue;
            }
            notificationService.notifyYoungChildRequestPending(u, row);
        }
    }

    private UserAccount ensureHrOrAdmin() {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() != UserRole.HR && u.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ HCNS/ADMIN được duyệt");
        }
        return u;
    }

    private void ensureCanViewAsHr() {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() != UserRole.HR && u.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách đề xuất");
        }
    }

    private void ensureCanViewRequest(YoungChildRequest row) {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() == UserRole.ADMIN || u.getRole() == UserRole.HR) {
            return;
        }
        if (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(u.getId())) {
            return;
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đề xuất này");
    }

    private Map<String, Object> toMap(YoungChildRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", r.getEmployee().getId());
        m.put("employeeCode", r.getEmployee().getEmployeeCode());
        m.put("employeeName", r.getEmployee().getFullName());
        m.put("departmentName",
                r.getEmployee().getDepartment() != null ? r.getEmployee().getDepartment().getName() : null);
        m.put("year", r.getPeriodYear());
        m.put("month", r.getPeriodMonth());
        m.put("enabled", r.isEnabled());
        m.put("reason", r.getReason());
        m.put("status", r.getStatus().name());
        m.put("requestedByUsername", r.getRequestedBy() != null ? r.getRequestedBy().getUsername() : null);
        m.put("hrReviewerUsername", r.getHrReviewer() != null ? r.getHrReviewer().getUsername() : null);
        m.put("hrComment", r.getHrComment());
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }
}
