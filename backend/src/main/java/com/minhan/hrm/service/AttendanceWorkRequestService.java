package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceDayProcessor;
import com.minhan.hrm.attendance.AttendancePenaltyCalculator;
import com.minhan.hrm.attendance.AttendanceShiftSchedule;
import com.minhan.hrm.attendance.LeaveEntitlement;
import com.minhan.hrm.dto.attendance.AttendanceReviewDto;
import com.minhan.hrm.dto.attendance.AttendanceWorkRequestSubmitDto;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.AttendanceWorkRequestRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AttendanceWorkRequestService {

    private static final EnumSet<AttendanceRequestStatus> PENDING_HEAD = EnumSet.of(AttendanceRequestStatus.PENDING_HEAD);
    private static final EnumSet<AttendanceRequestStatus> PENDING_HR = EnumSet.of(AttendanceRequestStatus.PENDING_HR);
    private static final EnumSet<AttendanceRequestStatus> HEAD_HISTORY = EnumSet.of(
            AttendanceRequestStatus.HEAD_REJECTED,
            AttendanceRequestStatus.PENDING_HR,
            AttendanceRequestStatus.HR_REJECTED,
            AttendanceRequestStatus.APPROVED,
            AttendanceRequestStatus.APPROVED_NO_FINE);
    private static final EnumSet<AttendanceRequestStatus> HR_HISTORY = EnumSet.of(
            AttendanceRequestStatus.HR_REJECTED,
            AttendanceRequestStatus.APPROVED,
            AttendanceRequestStatus.APPROVED_NO_FINE);
    private static final EnumSet<UserRole> HEAD_ROLES = EnumSet.of(
            UserRole.ADMIN, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_NURSING);
    private static final EnumSet<UserRole> HR_ROLES = EnumSet.of(UserRole.ADMIN, UserRole.HR);
    /** Hệ số công điều động ngoài ca: 1 giờ thực tế = 1.5 giờ công. */
    public static final BigDecimal DEPLOYMENT_COEFFICIENT = new BigDecimal("1.5");
    /** Điều động trong ca — công cố định, không tính theo giờ. */
    public static final BigDecimal DEPLOYMENT_INSIDE_MORNING_UNITS = new BigDecimal("1.0");
    public static final BigDecimal DEPLOYMENT_INSIDE_AFTERNOON_UNITS = new BigDecimal("0.5");

    private final AttendanceWorkRequestRepository requestRepository;
    private final AttendanceRecordRepository attendanceRecordRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeService employeeService;
    private final AttendanceDayProcessor dayProcessor;
    private final NotificationService notificationService;
    private final UserAccountRepository userAccountRepository;
    private final AttendanceShiftScheduleService shiftScheduleService;

    @Transactional
    public Map<String, Object> submit(AttendanceWorkRequestSubmitDto dto) {
        if (dto.getRequestType() == AttendanceRequestType.DEPLOYMENT) {
            return createDeployment(dto);
        }
        Employee emp = employeeRepository.findByUserUsername(employeeService.currentUser().getUsername())
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "Tài khoản chưa gắn hồ sơ nhân viên"));
        validateSubmit(dto, emp);
        AttendanceShiftScope scope = dto.getShiftScope();
        if (dto.getRequestType() == AttendanceRequestType.LEAVE
                || dto.getRequestType() == AttendanceRequestType.BUSINESS_TRIP) {
            scope = AttendanceShiftScope.FULL_DAY;
        }
        boolean ranged = dto.getRequestType() == AttendanceRequestType.LEAVE
                || dto.getRequestType() == AttendanceRequestType.BUSINESS_TRIP;
        Integer forgotFineUnits = null;
        if (dto.getRequestType() == AttendanceRequestType.UPDATE && dto.getUpdateKind() != null) {
            AttendanceRecord existing = attendanceRecordRepository
                    .findByEmployeeAndWorkDate(emp, dto.getWorkDate())
                    .orElse(null);
            forgotFineUnits = AttendancePenaltyCalculator.forgotFineUnitsForUpdate(dto.getUpdateKind(), existing);
        }
        AttendanceWorkRequest req = AttendanceWorkRequest.builder()
                .employee(emp)
                .requestType(dto.getRequestType())
                .workDate(dto.getWorkDate())
                .endDate(ranged
                        ? (dto.getEndDate() != null ? dto.getEndDate() : dto.getWorkDate())
                        : null)
                .shiftScope(scope)
                .updateKind(dto.getUpdateKind())
                .reason(dto.getReason().trim())
                .location(dto.getRequestType() == AttendanceRequestType.BUSINESS_TRIP
                        && dto.getLocation() != null
                        ? dto.getLocation().trim()
                        : null)
                .requestedStart(dto.getRequestedStart())
                .requestedEnd(dto.getRequestedEnd())
                .requestedAfternoonStart(dto.getRequestedAfternoonStart())
                .requestedAfternoonEnd(dto.getRequestedAfternoonEnd())
                .explanationKind(dto.getExplanationKind())
                .explainedTime(dto.getExplainedTime())
                .explainedDepartureTime(dto.getExplainedDepartureTime())
                .explainedMorningIn(dto.getExplainedMorningIn())
                .explainedMorningOut(dto.getExplainedMorningOut())
                .explainedAfternoonIn(dto.getExplainedAfternoonIn())
                .explainedAfternoonOut(dto.getExplainedAfternoonOut())
                .forgotFineUnits(forgotFineUnits)
                .status(AttendanceRequestStatus.PENDING_HEAD)
                .build();
        req = requestRepository.save(req);
        notifyHeadNewRequest(req);
        return toMap(req);
    }

    /**
     * Trưởng phòng / điều dưỡng trưởng / ADMIN / HR tạo đơn điều động cho nhân viên —
     * áp dụng ngay (hệ số 1.5) và gửi thông báo cho nhân viên.
     */
    @Transactional
    public Map<String, Object> createDeployment(AttendanceWorkRequestSubmitDto dto) {
        UserAccount creator = employeeService.currentUser();
        if (!HEAD_ROLES.contains(creator.getRole()) && !HR_ROLES.contains(creator.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ trưởng phòng / điều dưỡng trưởng / HCNS được tạo đơn điều động");
        }
        if (dto.getEmployeeId() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần chọn nhân viên điều động");
        }
        Employee target = employeeRepository.findById(dto.getEmployeeId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));
        assertCanDeploy(creator, target);
        validateDeploymentTimes(dto);

        LocalTime start = dto.getRequestedStart();
        LocalTime end = dto.getRequestedEnd();
        if (start == null || end == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập giờ bắt đầu và kết thúc điều động");
        }
        AttendanceShiftScope scope = dto.getShiftScope() != null
                ? dto.getShiftScope()
                : AttendanceShiftScope.FULL_DAY;

        AttendanceWorkRequest req = AttendanceWorkRequest.builder()
                .employee(target)
                .requestType(AttendanceRequestType.DEPLOYMENT)
                .workDate(dto.getWorkDate())
                .endDate(null)
                .shiftScope(scope)
                .reason(dto.getReason().trim())
                .requestedStart(start)
                .requestedEnd(end)
                .requestedAfternoonStart(dto.getRequestedAfternoonStart())
                .requestedAfternoonEnd(dto.getRequestedAfternoonEnd())
                .status(AttendanceRequestStatus.APPROVED)
                .headReviewer(creator)
                .headReviewedAt(Instant.now())
                .headComment("Điều động bởi " + (creator.getUsername() != null ? creator.getUsername() : "lãnh đạo"))
                .build();
        req = requestRepository.save(req);
        applyApprovedDeployment(req);
        String creatorLabel = creator.getUsername() != null ? creator.getUsername() : "Lãnh đạo";
        if (target.getUser() != null) {
            notificationService.notifyStaffDeployment(target.getUser(), req, creatorLabel);
        }
        return toMap(req);
    }

    private void assertCanDeploy(UserAccount creator, Employee target) {
        if (creator.getRole() == UserRole.ADMIN || creator.getRole() == UserRole.HR) {
            return;
        }
        Employee self = employeeRepository.findByUser(creator)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản chưa gắn hồ sơ nhân viên"));
        if (!self.getDepartment().getId().equals(target.getDepartment().getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ điều động nhân viên cùng khoa/phòng");
        }
    }

    private void validateDeploymentTimes(AttendanceWorkRequestSubmitDto dto) {
        if (dto.getReason() == null || dto.getReason().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập nội dung điều động");
        }
        if (dto.getWorkDate() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần chọn ngày điều động");
        }
        LocalDate today = LocalDate.now();
        LocalDate currentMonthEnd = today.withDayOfMonth(today.lengthOfMonth());
        if (dto.getWorkDate().isAfter(currentMonthEnd)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không điều động quá hết tháng hiện tại");
        }
        if (dto.getRequestedStart() == null || dto.getRequestedEnd() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập giờ bắt đầu và kết thúc");
        }

        AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(dto.getEmployeeId(), dto.getWorkDate());
        boolean offDay = isOffOrEmptyWorkDay(dto.getEmployeeId(), dto.getWorkDate());
        AttendanceShiftScope scope = dto.getShiftScope() != null
                ? dto.getShiftScope()
                : AttendanceShiftScope.FULL_DAY;
        boolean insideShift = isInsideShiftDeployment(dto);

        if (insideShift) {
            // Trong ca: không kiểm tra giờ — công cố định theo ca
            if (scope == AttendanceShiftScope.FULL_DAY
                    && (dto.getRequestedAfternoonStart() == null || dto.getRequestedAfternoonEnd() == null)) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Điều động cả ngày trong ca cần xác nhận cả ca sáng và ca chiều");
            }
        } else {
            if (dto.getRequestedStart().equals(dto.getRequestedEnd())) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Giờ kết thúc phải khác giờ bắt đầu (có thể qua đêm)");
            }
            if (!offDay && overlapsPrimarySchedule(
                    dto.getRequestedStart(),
                    dto.getRequestedEnd(),
                    schedule.morningStart(),
                    schedule.morningEnd(),
                    schedule.afternoonStart(),
                    schedule.afternoonEnd())) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        String.format(
                                "Giờ điều động ngoài ca không được trùng ca chính (%s–%s, %s–%s). Chọn «Trong ca» để điều chỉnh công ca sáng/chiều ×1,5.",
                                schedule.morningStart(),
                                schedule.morningEnd(),
                                schedule.afternoonStart(),
                                schedule.afternoonEnd()));
            }
        }

        List<AttendanceWorkRequest> existing = requestRepository.findByEmployeeIdAndWorkDateAndRequestType(
                dto.getEmployeeId(), dto.getWorkDate(), AttendanceRequestType.DEPLOYMENT);
        boolean open = existing.stream().anyMatch(r ->
                r.getStatus() == AttendanceRequestStatus.APPROVED
                        || r.getStatus() == AttendanceRequestStatus.PENDING_HEAD
                        || r.getStatus() == AttendanceRequestStatus.PENDING_HR);
        if (open) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Nhân viên đã có đơn điều động trong ngày này");
        }
    }

    /**
     * Trong ca: MORNING / AFTERNOON, hoặc FULL_DAY kèm giờ chiều riêng
     * (cộng giờ từng ca, không tính nghỉ trưa).
     */
    private static boolean isInsideShiftDeployment(AttendanceWorkRequestSubmitDto dto) {
        if (dto.getShiftScope() == AttendanceShiftScope.MORNING
                || dto.getShiftScope() == AttendanceShiftScope.AFTERNOON) {
            return true;
        }
        return dto.getRequestedAfternoonStart() != null && dto.getRequestedAfternoonEnd() != null;
    }

    private static boolean isInsideShiftDeploymentFromRequest(AttendanceWorkRequest req) {
        if (req.getShiftScope() == AttendanceShiftScope.MORNING
                || req.getShiftScope() == AttendanceShiftScope.AFTERNOON) {
            return true;
        }
        return req.getRequestedAfternoonStart() != null && req.getRequestedAfternoonEnd() != null;
    }

    private record InsideDeploymentUnits(BigDecimal morning, BigDecimal afternoon, String label) {}

    private static InsideDeploymentUnits resolveInsideDeploymentUnits(AttendanceWorkRequest req) {
        if (req.getRequestedAfternoonStart() != null && req.getRequestedAfternoonEnd() != null) {
            return new InsideDeploymentUnits(
                    DEPLOYMENT_INSIDE_MORNING_UNITS,
                    DEPLOYMENT_INSIDE_AFTERNOON_UNITS,
                    "Cả ngày (sáng + chiều)");
        }
        if (req.getShiftScope() == AttendanceShiftScope.MORNING) {
            return new InsideDeploymentUnits(DEPLOYMENT_INSIDE_MORNING_UNITS, BigDecimal.ZERO, "Ca sáng");
        }
        if (req.getShiftScope() == AttendanceShiftScope.AFTERNOON) {
            return new InsideDeploymentUnits(BigDecimal.ZERO, DEPLOYMENT_INSIDE_AFTERNOON_UNITS, "Ca chiều");
        }
        return new InsideDeploymentUnits(BigDecimal.ZERO, BigDecimal.ZERO, "");
    }

    private static String formatDeploymentNoteToken(BigDecimal bonus, boolean replace) {
        String prefix = replace && bonus.compareTo(BigDecimal.ZERO) > 0 ? "=" : "+";
        return prefix + bonus.toPlainString();
    }

    private static BigDecimal nz(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }

    private static void validateInsideShiftTimes(
            AttendanceWorkRequestSubmitDto dto,
            AttendanceShiftScope scope,
            AttendanceShiftSchedule schedule) {
        if (scope == AttendanceShiftScope.MORNING) {
            if (!withinShift(dto.getRequestedStart(), dto.getRequestedEnd(),
                    schedule.morningStart(), schedule.morningEnd())) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        String.format("Giờ ca sáng phải nằm trong %s–%s",
                                schedule.morningStart(), schedule.morningEnd()));
            }
            return;
        }
        if (scope == AttendanceShiftScope.AFTERNOON) {
            if (!withinShift(dto.getRequestedStart(), dto.getRequestedEnd(),
                    schedule.afternoonStart(), schedule.afternoonEnd())) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        String.format("Giờ ca chiều phải nằm trong %s–%s",
                                schedule.afternoonStart(), schedule.afternoonEnd()));
            }
            return;
        }
        // FULL_DAY trong ca: sáng + chiều riêng, không tính nghỉ trưa
        if (dto.getRequestedAfternoonStart() == null || dto.getRequestedAfternoonEnd() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Điều động cả 2 ca cần nhập giờ ca sáng và ca chiều");
        }
        if (!withinShift(dto.getRequestedStart(), dto.getRequestedEnd(),
                schedule.morningStart(), schedule.morningEnd())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    String.format("Giờ ca sáng phải nằm trong %s–%s",
                            schedule.morningStart(), schedule.morningEnd()));
        }
        if (!withinShift(dto.getRequestedAfternoonStart(), dto.getRequestedAfternoonEnd(),
                schedule.afternoonStart(), schedule.afternoonEnd())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    String.format("Giờ ca chiều phải nằm trong %s–%s",
                            schedule.afternoonStart(), schedule.afternoonEnd()));
        }
    }

    private static boolean withinShift(LocalTime start, LocalTime end, LocalTime shiftStart, LocalTime shiftEnd) {
        if (start == null || end == null || !end.isAfter(start)) {
            return false;
        }
        return !start.isBefore(shiftStart) && !end.isAfter(shiftEnd);
    }

    /** Giao với ca sáng/chiều — hỗ trợ khung qua đêm. */
    private static boolean overlapsPrimarySchedule(
            LocalTime start,
            LocalTime end,
            LocalTime morningStart,
            LocalTime morningEnd,
            LocalTime afternoonStart,
            LocalTime afternoonEnd) {
        int s = start.toSecondOfDay();
        int e = end.toSecondOfDay();
        int[][] primary = {
                {morningStart.toSecondOfDay(), morningEnd.toSecondOfDay()},
                {afternoonStart.toSecondOfDay(), afternoonEnd.toSecondOfDay()}
        };
        int[][] segments;
        if (e > s) {
            segments = new int[][] {{s, e}};
        } else {
            segments = new int[][] {{s, 24 * 3600}, {0, e}};
        }
        for (int[] seg : segments) {
            for (int[] p : primary) {
                if (seg[0] < p[1] && p[0] < seg[1]) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Ngày nghỉ / chưa có dữ liệu chấm — được điều động cả trong giờ ca chính (cộng công).
     * Có công (PRESENT/PARTIAL/…) — điều động trong ca thay công ca đó bằng mức ×1,5;
     * ngoài ca vẫn cộng thêm vào cột ngoài giờ.
     */
    private boolean isOffOrEmptyWorkDay(Long employeeId, LocalDate workDate) {
        Employee emp = employeeRepository.findById(employeeId).orElse(null);
        if (emp == null) {
            return true;
        }
        return attendanceRecordRepository.findByEmployeeAndWorkDate(emp, workDate)
                .map(r -> {
                    String st = r.getStatus();
                    if (st == null || st.isBlank()) {
                        return true;
                    }
                    return "ABSENT".equals(st) || "LEAVE".equals(st) || "BUSINESS_TRIP".equals(st);
                })
                .orElse(true);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> myRequests() {
        Employee emp = employeeRepository.findByUserUsername(employeeService.currentUser().getUsername())
                .orElse(null);
        if (emp == null) {
            return List.of();
        }
        return requestRepository.findByEmployeeIdOrderByCreatedAtDesc(emp.getId()).stream()
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> pendingForReviewer() {
        UserAccount user = employeeService.currentUser();
        if (HEAD_ROLES.contains(user.getRole())) {
            return requestRepository.findByStatusInOrderByCreatedAtAsc(PENDING_HEAD).stream()
                    .map(this::toMap)
                    .collect(Collectors.toList());
        }
        if (HR_ROLES.contains(user.getRole())) {
            return requestRepository.findByStatusInOrderByCreatedAtAsc(PENDING_HR).stream()
                    .map(this::toMap)
                    .collect(Collectors.toList());
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền duyệt đơn công");
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> reviewHistoryForReviewer() {
        UserAccount user = employeeService.currentUser();
        EnumSet<AttendanceRequestStatus> statuses;
        if (user.getRole() == UserRole.ADMIN) {
            statuses = EnumSet.copyOf(HEAD_HISTORY);
            statuses.addAll(HR_HISTORY);
        } else if (HEAD_ROLES.contains(user.getRole())) {
            statuses = HEAD_HISTORY;
        } else if (HR_ROLES.contains(user.getRole())) {
            statuses = HR_HISTORY;
        } else {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem lịch sử duyệt");
        }
        return requestRepository.findByStatusInOrderByUpdatedAtDesc(statuses).stream()
                .limit(100)
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    @Transactional
    public Map<String, Object> headReview(Long id, AttendanceReviewDto dto) {
        UserAccount reviewer = employeeService.currentUser();
        if (!HEAD_ROLES.contains(reviewer.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Ban giám đốc / Trưởng phòng duyệt bước 1");
        }
        AttendanceWorkRequest req = requirePendingHead(id);
        req.setHeadReviewer(reviewer);
        req.setHeadReviewedAt(Instant.now());
        req.setHeadComment(dto.getComment());
        if (Boolean.FALSE.equals(dto.getApproved())) {
            req.setStatus(AttendanceRequestStatus.HEAD_REJECTED);
            requestRepository.save(req);
            notificationService.notifyAttendanceRequestResult(req.getEmployee().getUser(), req, false);
            return toMap(req);
        }
        req.setStatus(AttendanceRequestStatus.PENDING_HR);
        requestRepository.save(req);
        notifyHrNewRequest(req);
        return toMap(req);
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, AttendanceReviewDto dto) {
        UserAccount reviewer = employeeService.currentUser();
        if (!HR_ROLES.contains(reviewer.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ HCNS duyệt bước 2");
        }
        AttendanceWorkRequest req = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy đơn"));
        if (req.getStatus() != AttendanceRequestStatus.PENDING_HR) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn không ở trạng thái chờ HCNS");
        }
        req.setHrReviewer(reviewer);
        req.setHrReviewedAt(Instant.now());
        req.setHrComment(dto.getComment());
        if (Boolean.FALSE.equals(dto.getApproved())) {
            req.setStatus(AttendanceRequestStatus.HR_REJECTED);
            requestRepository.save(req);
            notificationService.notifyAttendanceRequestResult(req.getEmployee().getUser(), req, false);
            return toMap(req);
        }
        boolean waive = Boolean.TRUE.equals(dto.getWaiveForgotFine());
        if (req.getRequestType() == AttendanceRequestType.UPDATE) {
            req.setHrWaiveForgotFine(waive);
            req.setStatus(waive ? AttendanceRequestStatus.APPROVED_NO_FINE : AttendanceRequestStatus.APPROVED);
            applyApprovedUpdate(req);
        } else if (req.getRequestType() == AttendanceRequestType.LEAVE) {
            req.setStatus(AttendanceRequestStatus.APPROVED);
            applyApprovedLeave(req);
        } else if (req.getRequestType() == AttendanceRequestType.BUSINESS_TRIP) {
            req.setStatus(AttendanceRequestStatus.APPROVED);
            applyApprovedBusinessTrip(req);
        } else if (req.getRequestType() == AttendanceRequestType.DEPLOYMENT) {
            req.setStatus(AttendanceRequestStatus.APPROVED);
            applyApprovedDeployment(req);
        } else {
            req.setStatus(AttendanceRequestStatus.APPROVED);
            applyApprovedExplanation(req);
        }
        requestRepository.save(req);
        notificationService.notifyAttendanceRequestResult(req.getEmployee().getUser(), req, true);
        return toMap(req);
    }

    @Transactional
    public Map<String, Object> withdraw(Long id) {
        Employee emp = requireSelfEmployee();
        AttendanceWorkRequest req = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy đơn"));
        if (!req.getEmployee().getId().equals(emp.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ người gửi đơn mới được thu hồi");
        }
        if (req.getStatus() != AttendanceRequestStatus.PENDING_HEAD
                && req.getStatus() != AttendanceRequestStatus.PENDING_HR) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Chỉ thu hồi được đơn đang chờ duyệt (chưa được HCNS duyệt)");
        }
        AttendanceRequestStatus previous = req.getStatus();
        req.setStatus(AttendanceRequestStatus.WITHDRAWN);
        requestRepository.save(req);
        notificationService.notifyAttendanceRequestWithdrawn(req, previous);
        return toMap(req);
    }

    private void applyApprovedExplanation(AttendanceWorkRequest req) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(req.getEmployee(), req.getWorkDate())
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(req.getEmployee())
                        .workDate(req.getWorkDate())
                        .status("ABSENT")
                        .build());

        boolean applied = false;
        if (req.getExplainedMorningIn() != null) {
            dayProcessor.applyExplainedTime(
                    rec, AttendanceShiftScope.MORNING, ExplanationKind.LATE_ARRIVAL, req.getExplainedMorningIn());
            applied = true;
        }
        if (req.getExplainedMorningOut() != null) {
            dayProcessor.applyExplainedTime(
                    rec, AttendanceShiftScope.MORNING, ExplanationKind.EARLY_DEPARTURE, req.getExplainedMorningOut());
            applied = true;
        }
        if (req.getExplainedAfternoonIn() != null) {
            dayProcessor.applyExplainedTime(
                    rec, AttendanceShiftScope.AFTERNOON, ExplanationKind.LATE_ARRIVAL, req.getExplainedAfternoonIn());
            applied = true;
        }
        if (req.getExplainedAfternoonOut() != null) {
            dayProcessor.applyExplainedTime(
                    rec, AttendanceShiftScope.AFTERNOON, ExplanationKind.EARLY_DEPARTURE, req.getExplainedAfternoonOut());
            applied = true;
        }

        if (!applied) {
            // Legacy: explainedTime / explainedDepartureTime + shiftScope
            LocalTime arrival = req.getExplainedTime();
            LocalTime departure = req.getExplainedDepartureTime();
            if (departure == null && arrival != null && req.getExplanationKind() == ExplanationKind.EARLY_DEPARTURE) {
                departure = arrival;
                arrival = null;
            }
            if (arrival == null && departure == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn giải trình thiếu thời gian");
            }
            AttendanceShiftScope scope = req.getShiftScope();
            if (arrival != null) {
                AttendanceShiftScope lateScope = scope == AttendanceShiftScope.FULL_DAY
                        ? AttendanceShiftScope.MORNING : scope;
                dayProcessor.applyExplainedTime(rec, lateScope, ExplanationKind.LATE_ARRIVAL, arrival);
            }
            if (departure != null) {
                AttendanceShiftScope earlyScope = scope == AttendanceShiftScope.FULL_DAY
                        ? AttendanceShiftScope.AFTERNOON : scope;
                dayProcessor.applyExplainedTime(rec, earlyScope, ExplanationKind.EARLY_DEPARTURE, departure);
            }
        }

        rec.setNote(appendNote(rec.getNote(), "Giải trình công đã duyệt — tính phạt theo giờ giải trình"));
        attendanceRecordRepository.save(rec);
    }

    private void applyApprovedUpdate(AttendanceWorkRequest req) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(req.getEmployee(), req.getWorkDate())
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(req.getEmployee())
                        .workDate(req.getWorkDate())
                        .status("ABSENT")
                        .build());
        AttendanceShiftScope scope = req.getShiftScope();
        if (req.getUpdateKind() == AttendanceUpdateKind.MORNING_SUPPLEMENT) {
            scope = AttendanceShiftScope.MORNING;
        } else if (req.getUpdateKind() == AttendanceUpdateKind.AFTERNOON_SUPPLEMENT) {
            scope = AttendanceShiftScope.AFTERNOON;
        } else if (req.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT) {
            scope = AttendanceShiftScope.FULL_DAY;
        }
        if (req.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT) {
            dayProcessor.applyManualFullDay(
                    rec,
                    req.getRequestedStart(),
                    req.getRequestedEnd(),
                    req.getRequestedAfternoonStart(),
                    req.getRequestedAfternoonEnd());
        } else {
            dayProcessor.applyManualShift(rec, scope, req.getRequestedStart(), req.getRequestedEnd());
        }
        rec.setNote(appendNote(rec.getNote(), "Cập nhật công theo đơn đã duyệt"));
        attendanceRecordRepository.save(rec);
    }

    private void applyApprovedLeave(AttendanceWorkRequest req) {
        LocalDate from = req.getWorkDate();
        LocalDate to = req.getEndDate() != null ? req.getEndDate() : from;
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            applyLeaveDay(req.getEmployee(), d, req.getReason());
        }
    }

    private void applyApprovedBusinessTrip(AttendanceWorkRequest req) {
        LocalDate from = req.getWorkDate();
        LocalDate to = req.getEndDate() != null ? req.getEndDate() : from;
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            applyBusinessTripDay(req.getEmployee(), d, req.getReason(), req.getLocation());
        }
    }

    private void applyApprovedDeployment(AttendanceWorkRequest req) {
        LocalTime start = req.getRequestedStart();
        LocalTime end = req.getRequestedEnd();
        if (start == null || end == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn điều động thiếu khung giờ");
        }
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(req.getEmployee(), req.getWorkDate())
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(req.getEmployee())
                        .workDate(req.getWorkDate())
                        .status("ABSENT")
                        .morningWorkUnits(BigDecimal.ZERO)
                        .afternoonWorkUnits(BigDecimal.ZERO)
                        .overtimeWorkUnits(BigDecimal.ZERO)
                        .build());
        AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(req.getEmployee().getId(), req.getWorkDate());
        boolean insideShift = isInsideShiftDeploymentFromRequest(req);
        double dayHours = schedule.totalHours() > 0 ? schedule.totalHours() : 8.0;

        BigDecimal morningBonus = BigDecimal.ZERO;
        BigDecimal afternoonBonus = BigDecimal.ZERO;
        BigDecimal overtimeBonus = BigDecimal.ZERO;
        double actualHours;
        String timeLabel;

        if (insideShift) {
            InsideDeploymentUnits inside = resolveInsideDeploymentUnits(req);
            morningBonus = inside.morning();
            afternoonBonus = inside.afternoon();
            timeLabel = inside.label();
            actualHours = 0;
            if (morningBonus.compareTo(BigDecimal.ZERO) <= 0
                    && afternoonBonus.compareTo(BigDecimal.ZERO) <= 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ca điều động trong ca không hợp lệ");
            }
        } else {
            if (req.getRequestedStart().equals(req.getRequestedEnd())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Khung giờ điều động ngoài ca không hợp lệ");
            }
            actualHours = overtimeHours(start, end);
            timeLabel = start + "–" + end;
            overtimeBonus = dayBonusUnits(actualHours, dayHours);
            if (actualHours <= 0 || overtimeBonus.compareTo(BigDecimal.ZERO) <= 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Khung giờ điều động ngoài ca không hợp lệ");
            }
        }

        double creditedHours = insideShift
                ? morningBonus.add(afternoonBonus).doubleValue()
                : actualHours * DEPLOYMENT_COEFFICIENT.doubleValue();
        boolean hadWork = !isOffOrEmptyWorkDay(req.getEmployee().getId(), req.getWorkDate());
        boolean replaceShiftUnits = insideShift && hadWork;

        BigDecimal currentMorning = rec.getMorningWorkUnits() != null
                ? rec.getMorningWorkUnits() : BigDecimal.ZERO;
        BigDecimal currentAfternoon = rec.getAfternoonWorkUnits() != null
                ? rec.getAfternoonWorkUnits() : BigDecimal.ZERO;
        BigDecimal currentOvertime = rec.getOvertimeWorkUnits() != null
                ? rec.getOvertimeWorkUnits() : BigDecimal.ZERO;

        if (replaceShiftUnits) {
            if (morningBonus.compareTo(BigDecimal.ZERO) > 0) {
                rec.setMorningWorkUnits(morningBonus);
            }
            if (afternoonBonus.compareTo(BigDecimal.ZERO) > 0) {
                rec.setAfternoonWorkUnits(afternoonBonus);
            }
            rec.setOvertimeWorkUnits(
                    overtimeBonus.compareTo(BigDecimal.ZERO) > 0
                            ? currentOvertime.add(overtimeBonus)
                            : currentOvertime);
        } else {
            rec.setMorningWorkUnits(currentMorning.add(morningBonus));
            rec.setAfternoonWorkUnits(currentAfternoon.add(afternoonBonus));
            rec.setOvertimeWorkUnits(currentOvertime.add(overtimeBonus));
        }
        rec.setLateMinutesExempt(true);
        if (rec.getStatus() == null
                || "ABSENT".equals(rec.getStatus())
                || "PARTIAL".equals(rec.getStatus())) {
            BigDecimal total = nz(rec.getMorningWorkUnits())
                    .add(nz(rec.getAfternoonWorkUnits()))
                    .add(nz(rec.getOvertimeWorkUnits()));
            rec.setStatus(total.compareTo(new BigDecimal("0.99")) >= 0 ? "PRESENT" : "PARTIAL");
        }
        String morningToken = formatDeploymentNoteToken(morningBonus, replaceShiftUnits);
        String afternoonToken = formatDeploymentNoteToken(afternoonBonus, replaceShiftUnits);
        String noteLine;
        if (insideShift) {
            noteLine = String.format(
                    "Điều động trong ca ×%.1f: %s — %s công (%s sáng / %s chiều / +%s ngoài giờ)",
                    DEPLOYMENT_COEFFICIENT.doubleValue(),
                    timeLabel,
                    morningBonus.add(afternoonBonus).toPlainString(),
                    morningToken,
                    afternoonToken,
                    overtimeBonus.toPlainString());
        } else {
            noteLine = String.format(
                    "Điều động làm thêm ×%.1f: %s · %.2fh → %.2fh công (%s sáng / %s chiều / +%s ngoài giờ)",
                    DEPLOYMENT_COEFFICIENT.doubleValue(),
                    timeLabel,
                    actualHours,
                    creditedHours,
                    morningToken,
                    afternoonToken,
                    overtimeBonus.toPlainString());
        }
        if (req.getReason() != null && !req.getReason().isBlank()) {
            noteLine += ": " + req.getReason().trim();
        }
        rec.setNote(appendNote(stripProtectedDayNotes(rec.getNote()), noteLine));
        attendanceRecordRepository.save(rec);
    }

    /**
     * Công điều động = (giờ thực × 1,5) / giờ ngày.
     * Ví dụ: 5h sáng × 1,5 = 7,5h công → 7,5 / 8 = 0,94 công.
     */
    private static BigDecimal dayBonusUnits(double actualHours, double dayHours) {
        if (actualHours <= 0 || dayHours <= 0) {
            return BigDecimal.ZERO;
        }
        double credited = actualHours * DEPLOYMENT_COEFFICIENT.doubleValue();
        return BigDecimal.valueOf(credited / dayHours).setScale(2, RoundingMode.HALF_UP);
    }

    /** Số giờ làm thêm — hỗ trợ qua đêm (22:00–06:00 = 8h). */
    private static double overtimeHours(LocalTime start, LocalTime end) {
        long mins = ChronoUnit.MINUTES.between(start, end);
        if (mins == 0) {
            return 0;
        }
        if (mins < 0) {
            mins += 24 * 60;
        }
        return mins / 60.0;
    }

    private void applyLeaveDay(Employee emp, LocalDate workDate, String reason) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, workDate)
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(emp)
                        .workDate(workDate)
                        .status("ABSENT")
                        .build());
        AttendanceShiftSchedule schedule = shiftScheduleService.forDate(workDate);
        rec.setPunchTimesJson("[]");
        rec.setCheckIn(null);
        rec.setCheckOut(null);
        rec.setMorningCheckIn(null);
        rec.setMorningCheckOut(null);
        rec.setAfternoonCheckIn(null);
        rec.setAfternoonCheckOut(null);
        rec.setMorningWorkUnits(schedule.morningUnits());
        rec.setAfternoonWorkUnits(schedule.afternoonUnits());
        rec.setOvertimeWorkUnits(BigDecimal.ZERO);
        rec.setLateMinutes(0);
        rec.setLateMinutesExempt(true);
        rec.setForgotShifts(null);
        rec.setStatus("LEAVE");
        String noteLine = "Nghỉ phép đã duyệt";
        if (reason != null && !reason.isBlank()) {
            noteLine += ": " + reason.trim();
        }
        rec.setNote(appendNote(stripProtectedDayNotes(rec.getNote()), noteLine));
        attendanceRecordRepository.save(rec);
    }

    private void applyBusinessTripDay(Employee emp, LocalDate workDate, String reason, String location) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, workDate)
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(emp)
                        .workDate(workDate)
                        .status("ABSENT")
                        .build());
        AttendanceShiftSchedule schedule = shiftScheduleService.forDate(workDate);
        rec.setPunchTimesJson("[]");
        rec.setCheckIn(null);
        rec.setCheckOut(null);
        rec.setMorningCheckIn(null);
        rec.setMorningCheckOut(null);
        rec.setAfternoonCheckIn(null);
        rec.setAfternoonCheckOut(null);
        rec.setMorningWorkUnits(schedule.morningUnits());
        rec.setAfternoonWorkUnits(schedule.afternoonUnits());
        rec.setOvertimeWorkUnits(BigDecimal.ZERO);
        rec.setLateMinutes(0);
        rec.setLateMinutesExempt(true);
        rec.setForgotShifts(null);
        rec.setStatus("BUSINESS_TRIP");
        String noteLine = "Công tác đã duyệt";
        if (location != null && !location.isBlank()) {
            noteLine += " tại " + location.trim();
        }
        if (reason != null && !reason.isBlank()) {
            noteLine += ": " + reason.trim();
        }
        rec.setNote(appendNote(stripProtectedDayNotes(rec.getNote()), noteLine));
        attendanceRecordRepository.save(rec);
    }

    private static String stripProtectedDayNotes(String existing) {
        if (existing == null || existing.isBlank()) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (String part : existing.split(";")) {
            String p = part.trim();
            if (p.isEmpty()
                    || p.startsWith("Nghỉ phép đã duyệt")
                    || p.startsWith("Công tác đã duyệt")
                    || p.startsWith("Điều động")) {
                continue;
            }
            if (sb.length() > 0) {
                sb.append("; ");
            }
            sb.append(p);
        }
        return sb.toString();
    }

    private static String appendNote(String existing, String line) {
        if (existing == null || existing.isBlank()) {
            return line;
        }
        if (existing.contains(line)) {
            return existing;
        }
        return existing + "; " + line;
    }

    private void validateSubmit(AttendanceWorkRequestSubmitDto dto, Employee emp) {
        if (dto.getRequestType() == AttendanceRequestType.UPDATE) {
            if (dto.getUpdateKind() == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn cập nhật cần chọn loại ca");
            }
            if (dto.getRequestedStart() == null || dto.getRequestedEnd() == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập thời gian bắt đầu và kết thúc");
            }
            if (dto.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT
                    && (dto.getRequestedAfternoonStart() == null || dto.getRequestedAfternoonEnd() == null)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Bổ sung cả ngày cần nhập khung giờ ca sáng và ca chiều");
            }
        }
        if (dto.getRequestType() == AttendanceRequestType.EXPLANATION) {
            boolean hasSlot = dto.getExplainedMorningIn() != null
                    || dto.getExplainedMorningOut() != null
                    || dto.getExplainedAfternoonIn() != null
                    || dto.getExplainedAfternoonOut() != null;
            boolean hasArrival = dto.getExplainedTime() != null;
            boolean hasDeparture = dto.getExplainedDepartureTime() != null;
            boolean legacy = dto.getExplanationKind() != null && dto.getExplainedTime() != null;
            if (!hasSlot && !hasArrival && !hasDeparture && !legacy) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Cần chọn ít nhất một khung giờ cần giải trình và nhập giờ thay thế");
            }
        }
        if (dto.getRequestType() == AttendanceRequestType.LEAVE) {
            LocalDate end = dto.getEndDate() != null ? dto.getEndDate() : dto.getWorkDate();
            if (end.isBefore(dto.getWorkDate())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
            }
            int requestDays = LeaveEntitlement.calendarDaysInclusive(dto.getWorkDate(), end);
            Map<String, Object> bal = leaveBalanceFor(emp, dto.getWorkDate().getYear());
            int remaining = ((Number) bal.get("remainingDays")).intValue();
            if (requestDays > remaining) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        String.format(
                                "Vượt hạn mức phép năm %d: còn %d ngày, đơn xin %d ngày (tối đa %d ngày/năm).",
                                dto.getWorkDate().getYear(),
                                remaining,
                                requestDays,
                                bal.get("entitlementDays")));
            }
            assertNoOverlappingRangedRequest(emp.getId(), AttendanceRequestType.LEAVE, dto.getWorkDate(), end,
                    "Khoảng ngày trùng với đơn nghỉ phép khác (đang chờ hoặc đã duyệt)");
        } else if (dto.getRequestType() == AttendanceRequestType.BUSINESS_TRIP) {
            LocalDate end = dto.getEndDate() != null ? dto.getEndDate() : dto.getWorkDate();
            if (end.isBefore(dto.getWorkDate())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
            }
            if (dto.getLocation() == null || dto.getLocation().isBlank()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập địa điểm công tác");
            }
            assertNoOverlappingRangedRequest(emp.getId(), AttendanceRequestType.BUSINESS_TRIP, dto.getWorkDate(), end,
                    "Khoảng ngày trùng với đơn công tác khác (đang chờ hoặc đã duyệt)");
        } else {
            List<AttendanceWorkRequest> existing = requestRepository.findByEmployeeIdAndWorkDateAndRequestType(
                    emp.getId(), dto.getWorkDate(), dto.getRequestType());
            boolean open = existing.stream().anyMatch(r ->
                    r.getStatus() == AttendanceRequestStatus.PENDING_HEAD
                            || r.getStatus() == AttendanceRequestStatus.PENDING_HR);
            if (open) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Đã có đơn đang chờ duyệt cho ngày này");
            }
        }
    }

    private void assertNoOverlappingRangedRequest(
            Long employeeId,
            AttendanceRequestType type,
            LocalDate from,
            LocalDate to,
            String message) {
        EnumSet<AttendanceRequestStatus> blocking = EnumSet.of(
                AttendanceRequestStatus.PENDING_HEAD,
                AttendanceRequestStatus.PENDING_HR,
                AttendanceRequestStatus.APPROVED);
        List<AttendanceWorkRequest> ranged = requestRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .filter(r -> r.getRequestType() == type)
                .filter(r -> blocking.contains(r.getStatus()))
                .toList();
        for (AttendanceWorkRequest r : ranged) {
            LocalDate rFrom = r.getWorkDate();
            LocalDate rTo = r.getEndDate() != null ? r.getEndDate() : rFrom;
            boolean overlap = !from.isAfter(rTo) && !to.isBefore(rFrom);
            if (overlap) {
                throw new ApiException(HttpStatus.BAD_REQUEST, message);
            }
        }
    }

    @Transactional(readOnly = true)
    public Map<String, Object> myLeaveBalance(Integer year) {
        Employee emp = requireSelfEmployee();
        int y = year != null ? year : LocalDate.now().getYear();
        return leaveBalanceFor(emp, y);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> employeeLeaveBalance(Long employeeId, Integer year) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        UserAccount current = employeeService.currentUser();
        if (current.getRole() != UserRole.ADMIN && current.getRole() != UserRole.HR
                && current.getRole() != UserRole.HEAD_DEPARTMENT && current.getRole() != UserRole.HEAD_NURSING) {
            Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
            if (self == null || !self.getId().equals(emp.getId())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem hạn mức phép");
            }
        }
        int y = year != null ? year : LocalDate.now().getYear();
        return leaveBalanceFor(emp, y);
    }

    private Map<String, Object> leaveBalanceFor(Employee emp, int year) {
        LocalDate yearStart = LocalDate.of(year, 1, 1);
        LocalDate yearEnd = LocalDate.of(year, 12, 31);
        LocalDate asOf = LocalDate.now().getYear() == year ? LocalDate.now() : yearEnd;
        int entitlement = LeaveEntitlement.entitlementDays(emp.getHireDate(), asOf);
        int years = LeaveEntitlement.yearsOfService(emp.getHireDate(), asOf);

        EnumSet<AttendanceRequestStatus> usedStatuses = EnumSet.of(AttendanceRequestStatus.APPROVED);
        EnumSet<AttendanceRequestStatus> pendingStatuses = EnumSet.of(
                AttendanceRequestStatus.PENDING_HEAD, AttendanceRequestStatus.PENDING_HR);

        int usedDays = sumLeaveDays(emp.getId(), yearStart, yearEnd, usedStatuses);
        int pendingDays = sumLeaveDays(emp.getId(), yearStart, yearEnd, pendingStatuses);
        int remaining = Math.max(0, entitlement - usedDays - pendingDays);

        Map<String, Object> m = new LinkedHashMap<>();
        m.put("employeeId", emp.getId());
        m.put("year", year);
        m.put("hireDate", emp.getHireDate() != null ? emp.getHireDate().toString() : "");
        m.put("yearsOfService", years);
        m.put("entitlementDays", entitlement);
        m.put("usedDays", usedDays);
        m.put("pendingDays", pendingDays);
        m.put("remainingDays", remaining);
        m.put("overLimit", usedDays + pendingDays > entitlement);
        m.put("warning", remaining <= 2
                ? String.format("Còn %d/%d ngày phép năm %d — lưu ý không vượt hạn mức.", remaining, entitlement, year)
                : "");
        return m;
    }

    private int sumLeaveDays(
            Long employeeId, LocalDate yearStart, LocalDate yearEnd, EnumSet<AttendanceRequestStatus> statuses) {
        return requestRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .filter(r -> r.getRequestType() == AttendanceRequestType.LEAVE)
                .filter(r -> statuses.contains(r.getStatus()))
                .mapToInt(r -> {
                    LocalDate from = r.getWorkDate();
                    LocalDate to = r.getEndDate() != null ? r.getEndDate() : from;
                    // Chỉ đếm phần giao với năm
                    LocalDate a = from.isBefore(yearStart) ? yearStart : from;
                    LocalDate b = to.isAfter(yearEnd) ? yearEnd : to;
                    if (b.isBefore(a)) {
                        return 0;
                    }
                    return LeaveEntitlement.calendarDaysInclusive(a, b);
                })
                .sum();
    }

    private Employee requireSelfEmployee() {
        return employeeRepository.findByUserUsername(employeeService.currentUser().getUsername())
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "Tài khoản chưa gắn hồ sơ nhân viên"));
    }

    private AttendanceWorkRequest requirePendingHead(Long id) {
        AttendanceWorkRequest req = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy đơn"));
        if (req.getStatus() != AttendanceRequestStatus.PENDING_HEAD) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn không ở trạng thái chờ lãnh đạo");
        }
        return req;
    }

    private void notifyHeadNewRequest(AttendanceWorkRequest req) {
        userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_NURSING))
                .forEach(u -> notificationService.notifyAttendanceRequestPending(u, req, "HEAD"));
    }

    private void notifyHrNewRequest(AttendanceWorkRequest req) {
        userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HR))
                .forEach(u -> notificationService.notifyAttendanceRequestPending(u, req, "HR"));
    }

    private Map<String, Object> toMap(AttendanceWorkRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", r.getEmployee().getId());
        m.put("employeeName", r.getEmployee().getFullName());
        m.put("department", r.getEmployee().getDepartment().getName());
        m.put("requestType", r.getRequestType().name());
        m.put("workDate", r.getWorkDate().toString());
        m.put("endDate", r.getEndDate() != null ? r.getEndDate().toString() : "");
        int rangedDays = (r.getRequestType() == AttendanceRequestType.LEAVE
                || r.getRequestType() == AttendanceRequestType.BUSINESS_TRIP)
                ? LeaveEntitlement.calendarDaysInclusive(
                        r.getWorkDate(), r.getEndDate() != null ? r.getEndDate() : r.getWorkDate())
                : 0;
        m.put("leaveDays", r.getRequestType() == AttendanceRequestType.LEAVE ? rangedDays : 0);
        m.put("tripDays", r.getRequestType() == AttendanceRequestType.BUSINESS_TRIP ? rangedDays : 0);
        m.put("shiftScope", r.getShiftScope().name());
        m.put("updateKind", r.getUpdateKind() != null ? r.getUpdateKind().name() : "");
        m.put("reason", r.getReason());
        m.put("location", r.getLocation() != null ? r.getLocation() : "");
        m.put("requestedStart", r.getRequestedStart() != null ? r.getRequestedStart().toString() : "");
        m.put("requestedEnd", r.getRequestedEnd() != null ? r.getRequestedEnd().toString() : "");
        if (r.getRequestType() == AttendanceRequestType.DEPLOYMENT
                && r.getRequestedStart() != null && r.getRequestedEnd() != null) {
            m.put("deploymentCoefficient", DEPLOYMENT_COEFFICIENT.doubleValue());
            if (isInsideShiftDeploymentFromRequest(r)) {
                InsideDeploymentUnits inside = resolveInsideDeploymentUnits(r);
                BigDecimal totalUnits = inside.morning().add(inside.afternoon());
                m.put("deploymentInsideShift", true);
                m.put("deploymentMorningUnits", inside.morning().doubleValue());
                m.put("deploymentAfternoonUnits", inside.afternoon().doubleValue());
                m.put("deploymentWorkUnits", totalUnits.doubleValue());
            } else {
                double actualHours = overtimeHours(r.getRequestedStart(), r.getRequestedEnd());
                double creditedHours = actualHours * DEPLOYMENT_COEFFICIENT.doubleValue();
                m.put("deploymentInsideShift", false);
                m.put("deploymentActualHours", Math.round(actualHours * 100.0) / 100.0);
                m.put("deploymentCreditedHours", Math.round(creditedHours * 100.0) / 100.0);
            }
        }
        m.put("requestedAfternoonStart",
                r.getRequestedAfternoonStart() != null ? r.getRequestedAfternoonStart().toString() : "");
        m.put("requestedAfternoonEnd",
                r.getRequestedAfternoonEnd() != null ? r.getRequestedAfternoonEnd().toString() : "");
        m.put("explanationKind", r.getExplanationKind() != null ? r.getExplanationKind().name() : "");
        m.put("explainedTime", r.getExplainedTime() != null ? r.getExplainedTime().toString() : "");
        m.put("explainedDepartureTime",
                r.getExplainedDepartureTime() != null ? r.getExplainedDepartureTime().toString() : "");
        m.put("explainedMorningIn",
                r.getExplainedMorningIn() != null ? r.getExplainedMorningIn().toString() : "");
        m.put("explainedMorningOut",
                r.getExplainedMorningOut() != null ? r.getExplainedMorningOut().toString() : "");
        m.put("explainedAfternoonIn",
                r.getExplainedAfternoonIn() != null ? r.getExplainedAfternoonIn().toString() : "");
        m.put("explainedAfternoonOut",
                r.getExplainedAfternoonOut() != null ? r.getExplainedAfternoonOut().toString() : "");
        m.put("status", r.getStatus().name());
        m.put("headComment", r.getHeadComment() != null ? r.getHeadComment() : "");
        m.put("hrComment", r.getHrComment() != null ? r.getHrComment() : "");
        m.put("headReviewedAt", r.getHeadReviewedAt() != null ? r.getHeadReviewedAt().toString() : "");
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : "");
        m.put("hrWaiveForgotFine", r.isHrWaiveForgotFine());
        if (r.getRequestType() == AttendanceRequestType.UPDATE) {
            m.put("forgotFineUnits", AttendancePenaltyCalculator.forgotFineUnitsForWorkRequest(r));
        }
        m.put("createdAt", r.getCreatedAt().toString());
        return m;
    }
}
