package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceShiftSchedule;
import com.minhan.hrm.dto.shiftconfig.ShiftConfigChangeCreateDto;
import com.minhan.hrm.dto.shiftconfig.ShiftConfigChangeReviewDto;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.NotificationRepository;
import com.minhan.hrm.repository.ShiftConfigChangeRequestRepository;
import com.minhan.hrm.service.support.RequestEditSupport;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.YearMonth;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class ShiftConfigChangeRequestService {

    private static final BigDecimal DEFAULT_MORNING_UNITS = new BigDecimal("0.66666667");
    private static final BigDecimal DEFAULT_AFTERNOON_UNITS = new BigDecimal("0.33333333");

    private final ShiftConfigChangeRequestRepository requestRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeLinkService employeeLinkService;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeService employeeService;
    private final AttendanceShiftScheduleService shiftScheduleService;
    private final AttendanceService attendanceService;
    private final NotificationService notificationService;
    private final ApprovalSignatureService approvalSignatureService;
    private final NotificationRepository notificationRepository;

    @Transactional
    public Map<String, Object> create(ShiftConfigChangeCreateDto req) {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN && !EmployeeService.isHeadRole(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ Trưởng khoa/phòng hoặc Điều dưỡng trưởng được đề xuất chỉnh ca sáng/chiều");
        }
        Employee emp = employeeRepository.findById(req.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (emp.getStatus() == EmployeeStatus.TERMINATED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đề xuất cho nhân viên đã nghỉ việc");
        }
        employeeService.assertCanAccessEmployee(emp);

        validateTimes(req.getMorningStart(), req.getMorningEnd(),
                req.getAfternoonStart(), req.getAfternoonEnd());
        if (req.getSeason() == ShiftConfigChangeSeason.BOTH) {
            validateTimes(req.getWinterMorningStart(), req.getWinterMorningEnd(),
                    req.getWinterAfternoonStart(), req.getWinterAfternoonEnd());
        }
        BigDecimal morningUnits = nzUnits(req.getMorningUnits(), DEFAULT_MORNING_UNITS);
        BigDecimal afternoonUnits = nzUnits(req.getAfternoonUnits(), DEFAULT_AFTERNOON_UNITS);

        if (requestRepository.existsConflictingPending(
                emp, req.getSeason(), ShiftConfigChangeRequestStatus.PENDING_HR)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đã có đề xuất chỉnh ca " + seasonLabel(req.getSeason())
                            + " đang chờ HCNS duyệt cho nhân viên này");
        }

        ShiftConfigChangeRequest row = ShiftConfigChangeRequest.builder()
                .employee(emp)
                .season(req.getSeason())
                .morningStart(req.getMorningStart())
                .morningEnd(req.getMorningEnd())
                .afternoonStart(req.getAfternoonStart())
                .afternoonEnd(req.getAfternoonEnd())
                .winterMorningStart(req.getSeason() == ShiftConfigChangeSeason.BOTH
                        ? req.getWinterMorningStart() : null)
                .winterMorningEnd(req.getSeason() == ShiftConfigChangeSeason.BOTH
                        ? req.getWinterMorningEnd() : null)
                .winterAfternoonStart(req.getSeason() == ShiftConfigChangeSeason.BOTH
                        ? req.getWinterAfternoonStart() : null)
                .winterAfternoonEnd(req.getSeason() == ShiftConfigChangeSeason.BOTH
                        ? req.getWinterAfternoonEnd() : null)
                .morningUnits(morningUnits)
                .afternoonUnits(afternoonUnits)
                .reason(req.getReason() != null && !req.getReason().isBlank() ? req.getReason().trim() : null)
                .status(ShiftConfigChangeRequestStatus.PENDING_HR)
                .requestedBy(actor)
                .build();
        row = requestRepository.save(row);
        notifyHrPending(row);
        notificationService.notifyShiftConfigChangeSubmittedToEmployee(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> update(Long id, ShiftConfigChangeCreateDto req) {
        UserAccount actor = employeeService.currentUser();
        ShiftConfigChangeRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất chỉnh ca"));
        RequestEditSupport.ensureRequesterOrAdmin(actor, row.getRequestedBy(),
                "Không có quyền chỉnh sửa đề xuất này");
        RequestEditSupport.ensurePendingStatus(row.getStatus(), "đề xuất chỉnh ca");

        Employee emp = row.getEmployee();
        if (!emp.getId().equals(req.getEmployeeId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đổi nhân viên khi chỉnh sửa đề xuất");
        }
        employeeService.assertCanAccessEmployee(emp);

        validateTimes(req.getMorningStart(), req.getMorningEnd(),
                req.getAfternoonStart(), req.getAfternoonEnd());
        if (req.getSeason() == ShiftConfigChangeSeason.BOTH) {
            validateTimes(req.getWinterMorningStart(), req.getWinterMorningEnd(),
                    req.getWinterAfternoonStart(), req.getWinterAfternoonEnd());
        }
        BigDecimal morningUnits = nzUnits(req.getMorningUnits(), DEFAULT_MORNING_UNITS);
        BigDecimal afternoonUnits = nzUnits(req.getAfternoonUnits(), DEFAULT_AFTERNOON_UNITS);

        if (requestRepository.findByEmployee_IdOrderByCreatedAtDesc(emp.getId()).stream()
                .anyMatch(r -> !r.getId().equals(id)
                        && r.getStatus() == ShiftConfigChangeRequestStatus.PENDING_HR
                        && seasonsConflict(r.getSeason(), req.getSeason()))) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đã có đề xuất chỉnh ca " + seasonLabel(req.getSeason())
                            + " đang chờ HCNS duyệt cho nhân viên này");
        }

        row.setSeason(req.getSeason());
        row.setMorningStart(req.getMorningStart());
        row.setMorningEnd(req.getMorningEnd());
        row.setAfternoonStart(req.getAfternoonStart());
        row.setAfternoonEnd(req.getAfternoonEnd());
        row.setWinterMorningStart(req.getSeason() == ShiftConfigChangeSeason.BOTH
                ? req.getWinterMorningStart() : null);
        row.setWinterMorningEnd(req.getSeason() == ShiftConfigChangeSeason.BOTH
                ? req.getWinterMorningEnd() : null);
        row.setWinterAfternoonStart(req.getSeason() == ShiftConfigChangeSeason.BOTH
                ? req.getWinterAfternoonStart() : null);
        row.setWinterAfternoonEnd(req.getSeason() == ShiftConfigChangeSeason.BOTH
                ? req.getWinterAfternoonEnd() : null);
        row.setMorningUnits(morningUnits);
        row.setAfternoonUnits(afternoonUnits);
        row.setReason(req.getReason() != null && !req.getReason().isBlank() ? req.getReason().trim() : null);
        row = requestRepository.save(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingHr() {
        UserAccount actor = ensureCanViewAsHr();
        return requestRepository.findPendingWithDetails(ShiftConfigChangeRequestStatus.PENDING_HR).stream()
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
        ShiftConfigChangeRequest row = requestRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất chỉnh ca"));
        ensureCanViewRequest(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, ShiftConfigChangeReviewDto body) {
        UserAccount hr = ensureHrOrAdmin();
        ShiftConfigChangeRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất chỉnh ca"));
        if (row.getStatus() != ShiftConfigChangeRequestStatus.PENDING_HR
                && row.getStatus() != ShiftConfigChangeRequestStatus.REJECTED
                && row.getStatus() != ShiftConfigChangeRequestStatus.APPROVED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đề xuất đã hủy nên không thể đổi quyết định");
        }
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setHrReviewer(hr);
        row.setHrReviewedAt(Instant.now());
        row.setHrComment(body.getComment() != null && !body.getComment().isBlank()
                ? body.getComment().trim() : null);
        row.setHrSignaturePath(approvalSignatureService.snapshotForApproval(
                hr, "shift-config-change", row.getId(), "hr"));

        if (!approved) {
            row.setStatus(ShiftConfigChangeRequestStatus.REJECTED);
            requestRepository.save(row);
            notificationService.notifyShiftConfigChangeResult(row, false);
            return toMap(row);
        }

        applyApprovedSeasons(row);
        row.setStatus(ShiftConfigChangeRequestStatus.APPROVED);
        requestRepository.save(row);

        int recalculated = 0;
        String recalculateWarning = null;
        try {
            recalculated = recalculateSeasonMonths(row.getEmployee().getId(), row.getSeason());
        } catch (Exception e) {
            log.warn("Duyệt chỉnh ca nhưng tính lại công thất bại — employee {} season {}",
                    row.getEmployee().getId(), row.getSeason(), e);
            recalculateWarning = "Đã duyệt nhưng chưa tính lại được bảng công.";
        }

        notificationService.notifyShiftConfigChangeResult(row, true);
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
        ShiftConfigChangeRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất chỉnh ca"));
        boolean canCancel = actor.getRole() == UserRole.ADMIN
                || (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(actor.getId()));
        if (!canCancel) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền hủy đề xuất này");
        }
        if (row.getStatus() == ShiftConfigChangeRequestStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đề xuất đã thu hồi rồi");
        }
        row.setStatus(ShiftConfigChangeRequestStatus.CANCELLED);
        requestRepository.save(row);
        return toMap(row);
    }

    @Transactional
    public void revoke(Long id) {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ ADMIN được thu hồi và xoá đơn");
        }
        ShiftConfigChangeRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề xuất chỉnh ca"));
        notificationRepository.deleteByCategoryAndRelatedRequestId(
                NotificationCategory.SHIFT_CONFIG_CHANGE, id);
        requestRepository.delete(row);
    }

    private void applyApprovedSeasons(ShiftConfigChangeRequest row) {
        Long employeeId = row.getEmployee().getId();
        if (row.getSeason() == ShiftConfigChangeSeason.SUMMER || row.getSeason() == ShiftConfigChangeSeason.BOTH) {
            shiftScheduleService.applyMorningAfternoonFromApprovedRequest(
                    employeeId,
                    AttendanceShiftSeason.SUMMER,
                    row.getMorningStart(),
                    row.getMorningEnd(),
                    row.getAfternoonStart(),
                    row.getAfternoonEnd(),
                    row.getMorningUnits(),
                    row.getAfternoonUnits());
        }
        if (row.getSeason() == ShiftConfigChangeSeason.WINTER) {
            shiftScheduleService.applyMorningAfternoonFromApprovedRequest(
                    employeeId,
                    AttendanceShiftSeason.WINTER,
                    row.getMorningStart(),
                    row.getMorningEnd(),
                    row.getAfternoonStart(),
                    row.getAfternoonEnd(),
                    row.getMorningUnits(),
                    row.getAfternoonUnits());
        } else if (row.getSeason() == ShiftConfigChangeSeason.BOTH) {
            shiftScheduleService.applyMorningAfternoonFromApprovedRequest(
                    employeeId,
                    AttendanceShiftSeason.WINTER,
                    row.getWinterMorningStart(),
                    row.getWinterMorningEnd(),
                    row.getWinterAfternoonStart(),
                    row.getWinterAfternoonEnd(),
                    row.getMorningUnits(),
                    row.getAfternoonUnits());
        }
    }

    private int recalculateSeasonMonths(Long employeeId, ShiftConfigChangeSeason season) {
        int total = 0;
        YearMonth cursor = YearMonth.from(LocalDate.now());
        for (int i = 0; i < 6; i++) {
            LocalDate sample = cursor.atDay(Math.min(15, cursor.lengthOfMonth()));
            boolean summer = AttendanceShiftSchedule.isSummer(sample);
            boolean match = season == ShiftConfigChangeSeason.BOTH
                    || (season == ShiftConfigChangeSeason.SUMMER && summer)
                    || (season == ShiftConfigChangeSeason.WINTER && !summer);
            if (match) {
                total += attendanceService.recalculateEmployeeMonth(
                        employeeId, cursor.getYear(), cursor.getMonthValue());
            }
            cursor = cursor.plusMonths(1);
        }
        return total;
    }

    private void notifyHrPending(ShiftConfigChangeRequest row) {
        for (UserAccount u : userAccountRepository.findByRoleIn(List.of(UserRole.HR2, UserRole.HEAD_HR, UserRole.ADMIN))) {
            if (u.isEnabled()) {
                notificationService.notifyShiftConfigChangePending(u, row);
            }
        }
    }

    private static void validateTimes(
            LocalTime morningStart, LocalTime morningEnd,
            LocalTime afternoonStart, LocalTime afternoonEnd) {
        if (morningStart == null || morningEnd == null
                || afternoonStart == null || afternoonEnd == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu giờ ca sáng/chiều");
        }
        if (!morningStart.isBefore(morningEnd)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Giờ bắt đầu ca sáng phải trước giờ kết thúc");
        }
        if (!afternoonStart.isBefore(afternoonEnd)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Giờ bắt đầu ca chiều phải trước giờ kết thúc");
        }
    }

    private static BigDecimal nzUnits(BigDecimal value, BigDecimal fallback) {
        if (value == null || value.compareTo(BigDecimal.ZERO) <= 0) {
            return fallback;
        }
        return value.setScale(8, RoundingMode.HALF_UP);
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

    private void ensureCanViewRequest(ShiftConfigChangeRequest row) {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() == UserRole.ADMIN || EmployeeService.isHr2Role(u)) {
            return;
        }
        if (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(u.getId())) {
            return;
        }
        if (EmployeeService.isHeadRole(u) && employeeService.matchesHeadScope(u, row.getEmployee())) {
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

    static String seasonLabel(ShiftConfigChangeSeason season) {
        return switch (season) {
            case SUMMER -> "mùa hè";
            case WINTER -> "mùa đông";
            case BOTH -> "mùa hè và mùa đông";
        };
    }

    private static boolean seasonsConflict(ShiftConfigChangeSeason existing, ShiftConfigChangeSeason requested) {
        return existing == requested
                || existing == ShiftConfigChangeSeason.BOTH
                || requested == ShiftConfigChangeSeason.BOTH;
    }

    private static String timeOrNull(LocalTime t) {
        return t != null ? t.toString() : null;
    }

    private Map<String, Object> toMap(ShiftConfigChangeRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", r.getEmployee().getId());
        m.put("employeeCode", r.getEmployee().getEmployeeCode());
        m.put("employeeName", r.getEmployee().getFullName());
        m.put("positionTitle", r.getEmployee().getPosition() != null
                ? r.getEmployee().getPosition().getTitle() : null);
        m.put("departmentName",
                r.getEmployee().getDepartment() != null ? r.getEmployee().getDepartment().getName() : null);
        m.put("season", r.getSeason().name());
        m.put("seasonLabel", seasonLabel(r.getSeason()));
        m.put("morningStart", r.getMorningStart().toString());
        m.put("morningEnd", r.getMorningEnd().toString());
        m.put("afternoonStart", r.getAfternoonStart().toString());
        m.put("afternoonEnd", r.getAfternoonEnd().toString());
        m.put("winterMorningStart", timeOrNull(r.getWinterMorningStart()));
        m.put("winterMorningEnd", timeOrNull(r.getWinterMorningEnd()));
        m.put("winterAfternoonStart", timeOrNull(r.getWinterAfternoonStart()));
        m.put("winterAfternoonEnd", timeOrNull(r.getWinterAfternoonEnd()));
        m.put("morningUnits", r.getMorningUnits());
        m.put("afternoonUnits", r.getAfternoonUnits());
        m.put("reason", r.getReason());
        m.put("status", r.getStatus().name());
        m.put("requestedByUsername", r.getRequestedBy() != null ? r.getRequestedBy().getUsername() : null);
        m.put("hrReviewerUsername", r.getHrReviewer() != null ? r.getHrReviewer().getUsername() : null);
        m.put("hrComment", r.getHrComment());
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : null);
        m.put("hrSignatureUrl", r.getHrSignaturePath() != null && !r.getHrSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/shift-config-change/" + r.getId() + "/hr" : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }
}
