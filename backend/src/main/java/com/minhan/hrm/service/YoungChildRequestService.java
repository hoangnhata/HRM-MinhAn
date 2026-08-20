package com.minhan.hrm.service;

import com.minhan.hrm.dto.youngchild.YoungChildRequestCreateDto;
import com.minhan.hrm.dto.youngchild.YoungChildRequestReviewDto;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.NotificationRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.repository.YoungChildRequestRepository;
import com.minhan.hrm.service.support.RequestEditSupport;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class YoungChildRequestService {

    private final YoungChildRequestRepository requestRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeLinkService employeeLinkService;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeService employeeService;
    private final YoungChildHoursService youngChildHoursService;
    private final AttendanceService attendanceService;
    private final NotificationService notificationService;
    private final ApprovalSignatureService approvalSignatureService;
    private final NotificationRepository notificationRepository;

    @Transactional
    public Map<String, Object> create(YoungChildRequestCreateDto req) {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && !EmployeeService.isHeadRole(actor)
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
        LocalDate startDate = req.getStartDate();
        LocalDate endDate = req.getEndDate();
        if (endDate.isBefore(startDate)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc không được trước ngày bắt đầu");
        }
        if (endDate.isAfter(startDate.plusYears(1).minusDays(1))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Khoảng áp dụng chế độ nuôi con nhỏ không được quá 1 năm");
        }
        boolean hasAnyActiveDay = !youngChildHoursService
                .datesForEmployee(emp.getId(), startDate, endDate).isEmpty();
        if (enabled && hasAnyActiveDay) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đã có chế độ nuôi con nhỏ trùng một phần hoặc toàn bộ khoảng ngày đã chọn");
        }
        if (!enabled && !hasAnyActiveDay) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên chưa có chế độ nuôi con nhỏ trong khoảng ngày đã chọn");
        }
        if (requestRepository.existsOverlapping(
                emp, startDate, endDate, YoungChildRequestStatus.PENDING_HR)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đã có đề xuất nuôi con nhỏ đang chờ HCNS duyệt trùng khoảng thời gian này");
        }

        YoungChildRequest row = YoungChildRequest.builder()
                .employee(emp)
                .startDate(startDate)
                .endDate(endDate)
                .periodYear(startDate.getYear())
                .periodMonth(startDate.getMonthValue())
                .enabled(enabled)
                .reason(req.getReason() != null && !req.getReason().isBlank() ? req.getReason().trim() : null)
                .status(YoungChildRequestStatus.PENDING_HR)
                .requestedBy(actor)
                .build();
        row = requestRepository.save(row);
        notifyHrPending(row);
        notificationService.notifyYoungChildRequestSubmittedToEmployee(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> update(Long id, YoungChildRequestCreateDto req) {
        UserAccount actor = employeeService.currentUser();
        YoungChildRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất nuôi con nhỏ"));
        RequestEditSupport.ensureRequesterOrAdmin(actor, row.getRequestedBy(),
                "Không có quyền chỉnh sửa đề xuất này");
        RequestEditSupport.ensurePendingStatus(row.getStatus(), "đề xuất nuôi con nhỏ");

        Employee emp = row.getEmployee();
        if (!emp.getId().equals(req.getEmployeeId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đổi nhân viên khi chỉnh sửa đề xuất");
        }

        boolean enabled = Boolean.TRUE.equals(req.getEnabled());
        LocalDate startDate = req.getStartDate();
        LocalDate endDate = req.getEndDate();
        if (endDate.isBefore(startDate)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc không được trước ngày bắt đầu");
        }
        if (endDate.isAfter(startDate.plusYears(1).minusDays(1))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Khoảng áp dụng chế độ nuôi con nhỏ không được quá 1 năm");
        }
        boolean hasAnyActiveDay = !youngChildHoursService
                .datesForEmployee(emp.getId(), startDate, endDate).isEmpty();
        if (enabled && hasAnyActiveDay) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đã có chế độ nuôi con nhỏ trùng một phần hoặc toàn bộ khoảng ngày đã chọn");
        }
        if (!enabled && !hasAnyActiveDay) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên chưa có chế độ nuôi con nhỏ trong khoảng ngày đã chọn");
        }
        if (requestRepository.findPendingOverlapping(
                        emp.getId(), startDate, endDate, YoungChildRequestStatus.PENDING_HR).stream()
                .anyMatch(r -> !r.getId().equals(id))) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đã có đề xuất nuôi con nhỏ đang chờ HCNS duyệt trùng khoảng thời gian này");
        }

        row.setStartDate(startDate);
        row.setEndDate(endDate);
        row.setPeriodYear(startDate.getYear());
        row.setPeriodMonth(startDate.getMonthValue());
        row.setEnabled(enabled);
        row.setReason(req.getReason() != null && !req.getReason().isBlank() ? req.getReason().trim() : null);
        row = requestRepository.save(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingHr() {
        UserAccount actor = ensureCanViewAsHr();
        return requestRepository.findPendingWithDetails(YoungChildRequestStatus.PENDING_HR).stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listHistory() {
        UserAccount actor = ensureCanViewAsHr();
        return requestRepository.findHistoryWithDetails().stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
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
    public List<Map<String, Object>> listRelatedToMe() {
        Employee self = requireSelfEmployee();
        return requestRepository.findByEmployee_IdOrderByCreatedAtDesc(self.getId()).stream()
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
    public Map<String, Object> getPendingForEmployeePeriod(Long employeeId, LocalDate fromDate, LocalDate toDate) {
        return requestRepository.findPendingOverlapping(
                        employeeId, fromDate, toDate, YoungChildRequestStatus.PENDING_HR).stream()
                .findFirst().map(this::toMap).orElse(null);
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, YoungChildRequestReviewDto body) {
        UserAccount hr = ensureHrOrAdmin();
        YoungChildRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất nuôi con nhỏ"));
        if (row.getStatus() != YoungChildRequestStatus.PENDING_HR
                && row.getStatus() != YoungChildRequestStatus.REJECTED
                && row.getStatus() != YoungChildRequestStatus.APPROVED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đề xuất đã hủy nên không thể đổi quyết định");
        }
        YoungChildRequestStatus previousStatus = row.getStatus();
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setHrReviewer(hr);
        row.setHrReviewedAt(Instant.now());
        row.setHrComment(body.getComment() != null && !body.getComment().isBlank()
                ? body.getComment().trim() : null);
        row.setHrSignaturePath(approvalSignatureService.snapshotForApproval(hr, "young-child", row.getId(), "hr"));

        if (!approved) {
            if (previousStatus == YoungChildRequestStatus.APPROVED) {
                youngChildHoursService.setYoungChildPeriod(
                        row.getEmployee().getId(), row.getStartDate(), row.getEndDate(), !row.isEnabled());
                recalculateAffectedMonths(row);
            }
            row.setStatus(YoungChildRequestStatus.REJECTED);
            requestRepository.save(row);
            notificationService.notifyYoungChildRequestResult(row, false);
            return toMap(row);
        }

        youngChildHoursService.setYoungChildPeriod(
                row.getEmployee().getId(), row.getStartDate(), row.getEndDate(), row.isEnabled());
        row.setStatus(YoungChildRequestStatus.APPROVED);
        requestRepository.save(row);

        int recalculated = 0;
        String recalculateWarning = null;
        try {
            YearMonth cursor = YearMonth.from(row.getStartDate());
            YearMonth last = YearMonth.from(row.getEndDate());
            while (!cursor.isAfter(last)) {
                recalculated += attendanceService.recalculateEmployeeMonth(
                        row.getEmployee().getId(), cursor.getYear(), cursor.getMonthValue());
                cursor = cursor.plusMonths(1);
            }
        } catch (Exception e) {
            log.warn("Duyệt nuôi con nhỏ nhưng tính lại công thất bại — employee {} {} đến {}",
                    row.getEmployee().getId(), row.getStartDate(), row.getEndDate(), e);
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

    private void recalculateAffectedMonths(YoungChildRequest row) {
        try {
            YearMonth cursor = YearMonth.from(row.getStartDate());
            YearMonth last = YearMonth.from(row.getEndDate());
            while (!cursor.isAfter(last)) {
                attendanceService.recalculateEmployeeMonth(
                        row.getEmployee().getId(), cursor.getYear(), cursor.getMonthValue());
                cursor = cursor.plusMonths(1);
            }
        } catch (Exception e) {
            log.warn("Đổi quyết định nuôi con nhỏ nhưng tính lại công thất bại — employee {} {} đến {}",
                    row.getEmployee().getId(), row.getStartDate(), row.getEndDate(), e);
        }
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
        if (row.getStatus() == YoungChildRequestStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đề xuất đã thu hồi rồi");
        }
        if (row.getStatus() == YoungChildRequestStatus.APPROVED && row.isEnabled()) {
            youngChildHoursService.setYoungChildPeriod(
                    row.getEmployee().getId(), row.getStartDate(), row.getEndDate(), false);
            try {
                YearMonth cursor = YearMonth.from(row.getStartDate());
                YearMonth last = YearMonth.from(row.getEndDate());
                while (!cursor.isAfter(last)) {
                    attendanceService.recalculateEmployeeMonth(
                            row.getEmployee().getId(), cursor.getYear(), cursor.getMonthValue());
                    cursor = cursor.plusMonths(1);
                }
            } catch (Exception e) {
                log.warn("Thu hồi đơn nuôi con nhỏ nhưng tính lại công thất bại — request {}", id, e);
            }
            row.setEnabled(false);
        }
        row.setStatus(YoungChildRequestStatus.CANCELLED);
        requestRepository.save(row);
        return toMap(row);
    }

    /** ADMIN thu hồi: xoá hẳn đơn và thông báo liên quan. */
    @Transactional
    public void revoke(Long id) {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ ADMIN được thu hồi và xoá đơn");
        }
        YoungChildRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất nuôi con nhỏ"));
        if (row.getStatus() == YoungChildRequestStatus.APPROVED && row.isEnabled()) {
            youngChildHoursService.setYoungChildPeriod(
                    row.getEmployee().getId(), row.getStartDate(), row.getEndDate(), false);
            try {
                YearMonth cursor = YearMonth.from(row.getStartDate());
                YearMonth last = YearMonth.from(row.getEndDate());
                while (!cursor.isAfter(last)) {
                    attendanceService.recalculateEmployeeMonth(
                            row.getEmployee().getId(), cursor.getYear(), cursor.getMonthValue());
                    cursor = cursor.plusMonths(1);
                }
            } catch (Exception e) {
                log.warn("Thu hồi đơn nuôi con nhỏ nhưng tính lại công thất bại — request {}", id, e);
            }
        }
        notificationRepository.deleteByCategoryAndRelatedRequestId(NotificationCategory.YOUNG_CHILD, id);
        requestRepository.delete(row);
    }

    private void notifyHrPending(YoungChildRequest row) {
        List<UserAccount> hrs = userAccountRepository.findByRoleIn(List.of(UserRole.HR2, UserRole.HEAD_HR, UserRole.ADMIN));
        for (UserAccount u : hrs) {
            if (!u.isEnabled()) {
                continue;
            }
            notificationService.notifyYoungChildRequestPending(u, row);
        }
    }

    private UserAccount ensureHrOrAdmin() {
        UserAccount u = employeeService.currentUser();
        if (!EmployeeService.isHr2Role(u) && u.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ HCNS/ADMIN được duyệt");
        }
        return u;
    }

    private UserAccount ensureCanViewAsHr() {
        UserAccount u = employeeService.currentUser();
        if (!EmployeeService.isHr2Role(u)
                && u.getRole() != UserRole.ADMIN
                && !EmployeeService.isHeadRole(u)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách đề xuất");
        }
        return u;
    }

    private void ensureCanViewRequest(YoungChildRequest row) {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() == UserRole.ADMIN || EmployeeService.isHr2Role(u)) {
            return;
        }
        if (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(u.getId())) {
            return;
        }
        if (u.getRole() == UserRole.EMPLOYEE) {
            Long selfId = actorEmployeeId(u);
            if (selfId != null && row.getEmployee().getId().equals(selfId)) {
                return;
            }
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đề xuất này");
    }

    private Employee requireSelfEmployee() {
        UserAccount actor = employeeService.currentUser();
        return employeeLinkService.findLinkedEmployee(actor)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản chưa liên kết nhân viên"));
    }

    private Long actorEmployeeId(UserAccount actor) {
        return employeeLinkService.findLinkedEmployee(actor).map(Employee::getId).orElse(null);
    }

    private Map<String, Object> toMap(YoungChildRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", r.getEmployee().getId());
        m.put("employeeCode", r.getEmployee().getEmployeeCode());
        m.put("employeeName", r.getEmployee().getFullName());
        m.put("positionTitle", r.getEmployee().getPosition() != null
                ? r.getEmployee().getPosition().getTitle() : null);
        m.put("departmentName",
                r.getEmployee().getDepartment() != null ? r.getEmployee().getDepartment().getName() : null);
        m.put("year", r.getPeriodYear());
        m.put("month", r.getPeriodMonth());
        m.put("startDate", r.getStartDate().toString());
        m.put("endDate", r.getEndDate().toString());
        m.put("enabled", r.isEnabled());
        m.put("reason", r.getReason());
        m.put("status", r.getStatus().name());
        m.put("requestedByUsername", r.getRequestedBy() != null ? r.getRequestedBy().getUsername() : null);
        m.put("hrReviewerUsername", r.getHrReviewer() != null ? r.getHrReviewer().getUsername() : null);
        m.put("hrComment", r.getHrComment());
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : null);
        m.put("hrSignatureUrl", r.getHrSignaturePath() != null && !r.getHrSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/young-child/" + r.getId() + "/hr" : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }
}
