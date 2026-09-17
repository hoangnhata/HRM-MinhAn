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
import com.minhan.hrm.security.ApprovalAuthority;
import com.minhan.hrm.service.support.RequestEditSupport;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.ZoneId;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Collection;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class AttendanceWorkRequestService {

    private static final EnumSet<AttendanceRequestStatus> PENDING_HEAD = EnumSet.of(AttendanceRequestStatus.PENDING_HEAD);
    private static final EnumSet<AttendanceRequestStatus> PENDING_NURSING_HEAD =
            EnumSet.of(AttendanceRequestStatus.PENDING_NURSING_HEAD);
    private static final EnumSet<AttendanceRequestStatus> PENDING_HR = EnumSet.of(AttendanceRequestStatus.PENDING_HR);
    private static final EnumSet<AttendanceRequestStatus> PENDING_DIRECTOR = EnumSet.of(AttendanceRequestStatus.PENDING_DIRECTOR);
    private static final EnumSet<AttendanceRequestStatus> HEAD_HISTORY = EnumSet.of(
            AttendanceRequestStatus.HEAD_REJECTED,
            AttendanceRequestStatus.PENDING_NURSING_HEAD,
            AttendanceRequestStatus.NURSING_HEAD_REJECTED,
            AttendanceRequestStatus.PENDING_HR,
            AttendanceRequestStatus.HR_REJECTED,
            AttendanceRequestStatus.PENDING_DIRECTOR,
            AttendanceRequestStatus.DIRECTOR_REJECTED,
            AttendanceRequestStatus.APPROVED,
            AttendanceRequestStatus.APPROVED_NO_FINE);
    private static final EnumSet<AttendanceRequestStatus> NURSING_HEAD_HISTORY = EnumSet.of(
            AttendanceRequestStatus.NURSING_HEAD_REJECTED,
            AttendanceRequestStatus.PENDING_HR,
            AttendanceRequestStatus.HR_REJECTED,
            AttendanceRequestStatus.PENDING_DIRECTOR,
            AttendanceRequestStatus.DIRECTOR_REJECTED,
            AttendanceRequestStatus.APPROVED,
            AttendanceRequestStatus.APPROVED_NO_FINE);
    private static final EnumSet<AttendanceRequestStatus> HR_HISTORY = EnumSet.of(
            AttendanceRequestStatus.HR_REJECTED,
            AttendanceRequestStatus.PENDING_DIRECTOR,
            AttendanceRequestStatus.DIRECTOR_REJECTED,
            AttendanceRequestStatus.APPROVED,
            AttendanceRequestStatus.APPROVED_NO_FINE);
    private static final EnumSet<AttendanceRequestStatus> DIRECTOR_HISTORY = EnumSet.of(
            AttendanceRequestStatus.DIRECTOR_REJECTED,
            AttendanceRequestStatus.APPROVED,
            AttendanceRequestStatus.APPROVED_NO_FINE);
    private static final EnumSet<UserRole> HEAD_ROLES = EnumSet.of(
            UserRole.ADMIN, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_HR);
    private static final EnumSet<UserRole> NURSING_HEAD_ROLES = EnumSet.of(
            UserRole.ADMIN, UserRole.HEAD_NURSING);
    private static final EnumSet<UserRole> HR_APPROVER_ROLES = EnumSet.of(
            UserRole.ADMIN, UserRole.HR2, UserRole.HEAD_HR);
    private static final EnumSet<UserRole> HR_MANAGER_ROLES = EnumSet.of(UserRole.ADMIN, UserRole.HR);
    private static final EnumSet<UserRole> DIRECTOR_ROLES = EnumSet.of(UserRole.ADMIN, UserRole.DIRECTOR);
    /** Nghỉ chế độ (kết hôn / người thân mất) tối đa 3 ngày theo Điều 115 BLLĐ 2019. */
    public static final int PERSONAL_LEAVE_MAX_DAYS = 3;

    /** Các loại đơn theo khoảng ngày, khoá cả ngày làm việc. */
    private static boolean isRangedLeaveType(AttendanceRequestType type) {
        return type == AttendanceRequestType.LEAVE
                || type == AttendanceRequestType.UNPAID_LEAVE
                || type == AttendanceRequestType.PERSONAL_LEAVE
                || type == AttendanceRequestType.BUSINESS_TRIP;
    }

    /** Chính thức hưởng lương cơ bản; thử việc, thực tập nghỉ không lương. */
    static boolean isPersonalLeavePaid(Employee emp) {
        return emp != null && emp.getStatus() == EmployeeStatus.ACTIVE;
    }
    private static final ZoneId VN_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    /** Mốc "không giới hạn" cho cận trên lịch sử — MySQL không nhận tham số Instant null. */
    private static final Instant HISTORY_OPEN_END = Instant.parse("2100-01-01T00:00:00Z");
    /** Hệ số công điều động ngoài ca: 1 giờ thực tế = 1.5 giờ công. */
    public static final BigDecimal DEPLOYMENT_COEFFICIENT = new BigDecimal("1.5");
    /** Điều động cả ca sáng trong ca — tối đa 1 công (tỷ lệ theo giờ nếu làm một phần ca). */
    public static final BigDecimal DEPLOYMENT_INSIDE_MORNING_UNITS = new BigDecimal("1.0");
    /** Điều động cả ca chiều trong ca — tối đa 0,5 công (tỷ lệ theo giờ nếu làm một phần ca). */
    public static final BigDecimal DEPLOYMENT_INSIDE_AFTERNOON_UNITS = new BigDecimal("0.5");

    private final AttendanceWorkRequestRepository requestRepository;
    private final AttendanceRecordRepository attendanceRecordRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeLinkService employeeLinkService;
    private final EmployeeService employeeService;
    private final AttendanceDayProcessor dayProcessor;
    private final NotificationService notificationService;
    private final UserAccountRepository userAccountRepository;
    private final AttendanceShiftScheduleService shiftScheduleService;
    private final ApprovalSignatureService approvalSignatureService;
    private final ContinuousShiftService continuousShiftService;
    private final DutyShiftService dutyShiftService;

    @Transactional
    public Map<String, Object> submit(AttendanceWorkRequestSubmitDto dto) {
        if (dto.getRequestType() == AttendanceRequestType.BUSINESS_TRIP) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn công tác đã ngừng sử dụng; vui lòng tạo đơn đi Hội thảo");
        }
        if (dto.getRequestType() == AttendanceRequestType.DEPLOYMENT) {
            return createDeployment(dto);
        }
        Employee emp = dto.getRequestType() == AttendanceRequestType.EXPLANATION
                ? resolveExplanationEmployee(dto)
                : employeeService.requireLinkedEmployee();
        validateSubmit(dto, emp, null);
        AttendanceShiftScope scope = dto.getShiftScope();
        if (isRangedLeaveType(dto.getRequestType())) {
            scope = AttendanceShiftScope.FULL_DAY;
        }
        boolean continuousDay = continuousShiftService.isContinuousShift(emp.getId(), dto.getWorkDate());
        boolean twoPunchDay = continuousShiftService.isTwoPunchAttendance(emp.getId());
        AttendanceUpdateKind updateKind = dto.getUpdateKind();
        if ((dto.getRequestType() == AttendanceRequestType.UPDATE
                || dto.getRequestType() == AttendanceRequestType.EXPLANATION)
                && (continuousDay || twoPunchDay)) {
            scope = AttendanceShiftScope.FULL_DAY;
            if (dto.getRequestType() == AttendanceRequestType.UPDATE) {
                updateKind = AttendanceUpdateKind.FULL_DAY_SUPPLEMENT;
            }
        }
        boolean ranged = isRangedLeaveType(dto.getRequestType());
        Integer forgotFineUnits = null;
        if (dto.getRequestType() == AttendanceRequestType.UPDATE && updateKind != null) {
            AttendanceRecord existing = attendanceRecordRepository
                    .findByEmployeeAndWorkDate(emp, dto.getWorkDate())
                    .orElse(null);
            forgotFineUnits = AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                    updateKind, existing, continuousDay || twoPunchDay);
        }
        boolean personalLeave = dto.getRequestType() == AttendanceRequestType.PERSONAL_LEAVE;
        AttendanceWorkRequest req = AttendanceWorkRequest.builder()
                .personalLeaveKind(personalLeave ? dto.getPersonalLeaveKind() : null)
                .personalLeavePaid(personalLeave ? isPersonalLeavePaid(emp) : null)
                .employee(emp)
                .requestType(dto.getRequestType())
                .workDate(dto.getWorkDate())
                .endDate(ranged
                        ? (dto.getEndDate() != null ? dto.getEndDate() : dto.getWorkDate())
                        : null)
                .shiftScope(scope)
                .updateKind(updateKind)
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
        if (dto.getRequestType() == AttendanceRequestType.EXPLANATION) {
            snapshotExplanationOriginalPunches(req, emp, dto);
        }
        req = requestRepository.save(req);
        notifyHeadNewRequest(req);
        return toMap(req);
    }

    @Transactional
    public Map<String, Object> update(Long id, AttendanceWorkRequestSubmitDto dto) {
        if (dto.getRequestType() == AttendanceRequestType.BUSINESS_TRIP) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn công tác đã ngừng sử dụng; vui lòng tạo đơn hội thảo");
        }
        UserAccount actor = employeeService.currentUser();
        AttendanceWorkRequest req = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy đơn"));
        ensureCanEditWorkRequest(actor, req);
        if (dto.getRequestType() != req.getRequestType()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không được đổi loại đơn");
        }
        Employee emp = req.getEmployee();
        if (dto.getEmployeeId() != null && !dto.getEmployeeId().equals(emp.getId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không được đổi nhân viên");
        }
        dto.setEmployeeId(emp.getId());

        if (req.getRequestType() == AttendanceRequestType.DEPLOYMENT) {
            validateDeploymentTimes(dto, id);
            applyDeploymentFields(req, dto);
            req = requestRepository.save(req);
            return toMap(req);
        }

        validateSubmit(dto, emp, id);
        applyWorkRequestFields(req, dto, emp);
        req = requestRepository.save(req);
        return toMap(req);
    }

    private void ensureCanEditWorkRequest(UserAccount actor, AttendanceWorkRequest req) {
        RequestEditSupport.ensurePendingStatus(req.getStatus(), "đơn công");
        if (actor.getRole() == UserRole.ADMIN) {
            return;
        }
        if (req.getRequestType() == AttendanceRequestType.DEPLOYMENT) {
            if (req.getHeadReviewer() != null && req.getHeadReviewer().getId().equals(actor.getId())) {
                return;
            }
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ người lập đơn điều động hoặc ADMIN được chỉnh sửa");
        }
        Employee linked = employeeLinkService.findLinkedEmployee(actor).orElse(null);
        if (linked != null && linked.getId().equals(req.getEmployee().getId())) {
            return;
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ người lập đơn hoặc ADMIN được chỉnh sửa");
    }

    private void applyWorkRequestFields(
            AttendanceWorkRequest req, AttendanceWorkRequestSubmitDto dto, Employee emp) {
        AttendanceShiftScope scope = dto.getShiftScope();
        if (isRangedLeaveType(dto.getRequestType())) {
            scope = AttendanceShiftScope.FULL_DAY;
        }
        boolean continuousDay = continuousShiftService.isContinuousShift(emp.getId(), dto.getWorkDate());
        boolean twoPunchDay = continuousShiftService.isTwoPunchAttendance(emp.getId());
        AttendanceUpdateKind updateKind = dto.getUpdateKind();
        if ((dto.getRequestType() == AttendanceRequestType.UPDATE
                || dto.getRequestType() == AttendanceRequestType.EXPLANATION)
                && (continuousDay || twoPunchDay)) {
            scope = AttendanceShiftScope.FULL_DAY;
            if (dto.getRequestType() == AttendanceRequestType.UPDATE) {
                updateKind = AttendanceUpdateKind.FULL_DAY_SUPPLEMENT;
            }
        }
        boolean ranged = isRangedLeaveType(dto.getRequestType());
        Integer forgotFineUnits = null;
        if (dto.getRequestType() == AttendanceRequestType.UPDATE && updateKind != null) {
            AttendanceRecord existing = attendanceRecordRepository
                    .findByEmployeeAndWorkDate(emp, dto.getWorkDate())
                    .orElse(null);
            forgotFineUnits = AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                    updateKind, existing, continuousDay || twoPunchDay);
        }
        if (dto.getRequestType() == AttendanceRequestType.PERSONAL_LEAVE) {
            req.setPersonalLeaveKind(dto.getPersonalLeaveKind());
            req.setPersonalLeavePaid(isPersonalLeavePaid(emp));
        }
        req.setWorkDate(dto.getWorkDate());
        req.setEndDate(ranged
                ? (dto.getEndDate() != null ? dto.getEndDate() : dto.getWorkDate())
                : null);
        req.setShiftScope(scope);
        req.setUpdateKind(updateKind);
        req.setReason(dto.getReason().trim());
        req.setLocation(dto.getRequestType() == AttendanceRequestType.BUSINESS_TRIP
                && dto.getLocation() != null
                ? dto.getLocation().trim()
                : null);
        req.setRequestedStart(dto.getRequestedStart());
        req.setRequestedEnd(dto.getRequestedEnd());
        req.setRequestedAfternoonStart(dto.getRequestedAfternoonStart());
        req.setRequestedAfternoonEnd(dto.getRequestedAfternoonEnd());
        req.setExplanationKind(dto.getExplanationKind());
        req.setExplainedTime(dto.getExplainedTime());
        req.setExplainedDepartureTime(dto.getExplainedDepartureTime());
        req.setExplainedMorningIn(dto.getExplainedMorningIn());
        req.setExplainedMorningOut(dto.getExplainedMorningOut());
        req.setExplainedAfternoonIn(dto.getExplainedAfternoonIn());
        req.setExplainedAfternoonOut(dto.getExplainedAfternoonOut());
        req.setForgotFineUnits(forgotFineUnits);
        if (dto.getRequestType() == AttendanceRequestType.EXPLANATION) {
            snapshotExplanationOriginalPunches(req, emp, dto);
        }
    }

    private void applyDeploymentFields(AttendanceWorkRequest req, AttendanceWorkRequestSubmitDto dto) {
        AttendanceShiftScope scope = dto.getShiftScope() != null
                ? dto.getShiftScope()
                : AttendanceShiftScope.FULL_DAY;
        req.setWorkDate(dto.getWorkDate());
        req.setShiftScope(scope);
        req.setReason(dto.getReason().trim());
        req.setRequestedStart(dto.getRequestedStart());
        req.setRequestedEnd(dto.getRequestedEnd());
        req.setRequestedAfternoonStart(dto.getRequestedAfternoonStart());
        req.setRequestedAfternoonEnd(dto.getRequestedAfternoonEnd());
    }

    private Employee resolveExplanationEmployee(AttendanceWorkRequestSubmitDto dto) {
        UserAccount creator = employeeService.currentUser();
        if (creator.getRole() == UserRole.ADMIN) {
            if (dto.getEmployeeId() == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "ADMIN cần chọn nhân viên để tạo đơn giải trình");
            }
            return employeeRepository.findById(dto.getEmployeeId())
                    .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                            "Không tìm thấy nhân viên"));
        }
        // Mọi vai trò có hồ sơ NV liên kết đều giải trình được công của chính mình
        // (EMPLOYEE, HEAD_DEPARTMENT, HEAD_NURSING, …).
        Employee self = employeeService.requireLinkedEmployee();
        if (dto.getEmployeeId() != null && !dto.getEmployeeId().equals(self.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ được tạo đơn giải trình cho chính mình");
        }
        return self;
    }

    /** Ghi lại giờ máy chấm gốc của các mốc đang giải trình để hiển thị trước → sau. */
    private void snapshotExplanationOriginalPunches(
            AttendanceWorkRequest req, Employee emp, AttendanceWorkRequestSubmitDto dto) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, dto.getWorkDate())
                .orElse(null);
        if (rec == null) {
            return;
        }
        LocalTime morningIn = rec.getMorningCheckIn() != null ? rec.getMorningCheckIn() : rec.getCheckIn();
        LocalTime afternoonOut = rec.getAfternoonCheckOut() != null ? rec.getAfternoonCheckOut() : rec.getCheckOut();
        if (dto.getExplainedMorningIn() != null) {
            req.setOriginalMorningIn(morningIn);
        }
        if (dto.getExplainedMorningOut() != null) {
            req.setOriginalMorningOut(rec.getMorningCheckOut());
        }
        if (dto.getExplainedAfternoonIn() != null) {
            req.setOriginalAfternoonIn(rec.getAfternoonCheckIn());
        }
        if (dto.getExplainedAfternoonOut() != null) {
            req.setOriginalAfternoonOut(afternoonOut);
        }
        // Legacy 1-mốc: đi muộn / về sớm
        if (dto.getExplainedTime() != null
                && dto.getExplainedMorningIn() == null
                && dto.getExplainedAfternoonIn() == null) {
            if (dto.getExplanationKind() == ExplanationKind.EARLY_DEPARTURE) {
                req.setOriginalAfternoonOut(afternoonOut);
            } else {
                req.setOriginalMorningIn(morningIn);
            }
        }
        if (dto.getExplainedDepartureTime() != null && dto.getExplainedAfternoonOut() == null) {
            req.setOriginalAfternoonOut(afternoonOut);
        }
    }

    /**
     * Trưởng phòng (hoặc ADMIN) tạo đơn điều động cho nhân viên.
     * Luồng: trưởng lập → (khối ĐD: Trưởng phòng Điều dưỡng) → HCNS2 → Giám đốc.
     */
    @Transactional
    public Map<String, Object> createDeployment(AttendanceWorkRequestSubmitDto dto) {
        UserAccount creator = employeeService.currentUser();
        if (!HEAD_ROLES.contains(creator.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ trưởng phòng / điều dưỡng trưởng được tạo đơn điều động");
        }
        if (dto.getEmployeeId() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần chọn nhân viên điều động");
        }
        Employee target = employeeRepository.findById(dto.getEmployeeId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));
        assertCanDeploy(creator, target);
        validateDeploymentTimes(dto, null);

        LocalTime start = dto.getRequestedStart();
        LocalTime end = dto.getRequestedEnd();
        if (start == null || end == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập giờ bắt đầu và kết thúc điều động");
        }
        AttendanceShiftScope scope = dto.getShiftScope() != null
                ? dto.getShiftScope()
                : AttendanceShiftScope.FULL_DAY;

        boolean nursingBlock = NursingBlockClassifier.matchesNursingHeadScope(target);
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
                .status(nursingBlock
                        ? AttendanceRequestStatus.PENDING_NURSING_HEAD
                        : AttendanceRequestStatus.PENDING_HR)
                .headReviewer(creator)
                .headReviewedAt(Instant.now())
                .headComment("Trưởng khoa/phòng lập phiếu điều động")
                .build();
        req = requestRepository.save(req);
        if (nursingBlock) {
            notifyNursingHeadNewRequest(req);
        } else {
            notifyHrNewRequest(req);
        }
        if (target.getUser() != null) {
            notificationService.notifyStaffDeployment(
                    target.getUser(),
                    req,
                    employeeLinkService.findLinkedEmployee(creator)
                            .map(Employee::getFullName)
                            .orElse(creator.getUsername()));
        }
        return toMap(req);
    }

    private void assertCanDeploy(UserAccount creator, Employee target) {
        if (creator.getRole() == UserRole.ADMIN || creator.getRole() == UserRole.HR) {
            return;
        }
        Employee self = employeeLinkService.findLinkedEmployee(creator)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản chưa gắn hồ sơ nhân viên"));
        if (!self.getDepartment().getId().equals(target.getDepartment().getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ điều động nhân viên cùng khoa/phòng");
        }
    }

    private void validateDeploymentTimes(AttendanceWorkRequestSubmitDto dto, Long excludeId) {
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
        boolean continuous = continuousShiftService.isContinuousShift(dto.getEmployeeId(), dto.getWorkDate());
        boolean offDay = isOffOrEmptyWorkDay(dto.getEmployeeId(), dto.getWorkDate());
        AttendanceShiftScope scope = dto.getShiftScope() != null
                ? dto.getShiftScope()
                : AttendanceShiftScope.FULL_DAY;
        boolean insideShift = isInsideShiftDeployment(dto, continuous, schedule);

        if (continuous) {
            validateContinuousDeploymentTimes(dto, schedule, offDay, insideShift);
        } else if (insideShift) {
            if (scope == AttendanceShiftScope.FULL_DAY
                    && (dto.getRequestedAfternoonStart() == null || dto.getRequestedAfternoonEnd() == null)) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Điều động cả ngày trong ca cần xác nhận cả ca sáng và ca chiều");
            }
            validateInsideShiftTimes(dto, scope, schedule);
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

        List<AttendanceWorkRequest> existing = requestRepository.findByEmployeeIdAndWorkDateBetween(
                dto.getEmployeeId(), dto.getWorkDate().minusDays(1), dto.getWorkDate().plusDays(1));
        boolean overlapsExistingDeployment = existing.stream()
                .filter(r -> excludeId == null || !r.getId().equals(excludeId))
                .filter(r -> r.getRequestType() == AttendanceRequestType.DEPLOYMENT)
                .filter(AttendanceWorkRequestService::isOpenDeployment)
                .flatMap(r -> deploymentIntervals(r).stream())
                .anyMatch(existingInterval -> deploymentIntervals(dto).stream()
                        .anyMatch(requestedInterval -> requestedInterval.overlaps(existingInterval)));
        if (overlapsExistingDeployment) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Khung giờ điều động bị trùng với đơn điều động đang chờ duyệt hoặc đã duyệt");
        }
    }

    private void validateContinuousDeploymentTimes(
            AttendanceWorkRequestSubmitDto dto,
            AttendanceShiftSchedule schedule,
            boolean offDay,
            boolean insideShift) {
        if (dto.getRequestedAfternoonStart() != null || dto.getRequestedAfternoonEnd() != null) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Ca thông tầm: chỉ nhập một khung giờ vào–ra trong ngày (không tách sáng/chiều)");
        }
        LocalTime dayStart = schedule.continuousDayStart();
        LocalTime dayEnd = schedule.continuousDayEnd();
        if (insideShift) {
            if (!withinShift(dto.getRequestedStart(), dto.getRequestedEnd(), dayStart, dayEnd)) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        String.format("Giờ điều động trong ca thông tầm phải nằm trong %s–%s",
                                dayStart, dayEnd));
            }
            return;
        }
        if (dto.getRequestedStart().equals(dto.getRequestedEnd())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Giờ kết thúc phải khác giờ bắt đầu (có thể qua đêm)");
        }
        if (!offDay && overlapsPrimarySchedule(
                dto.getRequestedStart(),
                dto.getRequestedEnd(),
                dayStart,
                dayEnd,
                dayStart,
                dayEnd)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    String.format(
                            "Giờ điều động ngoài ca không được trùng ca thông tầm (%s–%s). Chọn «Trong ca» để điều chỉnh công ×1,5.",
                            dayStart, dayEnd));
        }
    }

    private static boolean isOpenDeployment(AttendanceWorkRequest request) {
        return request.getStatus() == AttendanceRequestStatus.APPROVED
                || request.getStatus() == AttendanceRequestStatus.PENDING_HEAD
                || request.getStatus() == AttendanceRequestStatus.PENDING_NURSING_HEAD
                || request.getStatus() == AttendanceRequestStatus.PENDING_HR
                || request.getStatus() == AttendanceRequestStatus.PENDING_DIRECTOR;
    }

    private static List<DeploymentInterval> deploymentIntervals(AttendanceWorkRequestSubmitDto dto) {
        return deploymentIntervals(dto.getWorkDate(), dto.getRequestedStart(), dto.getRequestedEnd(),
                dto.getRequestedAfternoonStart(), dto.getRequestedAfternoonEnd());
    }

    private static List<DeploymentInterval> deploymentIntervals(AttendanceWorkRequest request) {
        return deploymentIntervals(request.getWorkDate(), request.getRequestedStart(), request.getRequestedEnd(),
                request.getRequestedAfternoonStart(), request.getRequestedAfternoonEnd());
    }

    private static List<DeploymentInterval> deploymentIntervals(
            LocalDate workDate,
            LocalTime start,
            LocalTime end,
            LocalTime afternoonStart,
            LocalTime afternoonEnd) {
        List<DeploymentInterval> intervals = new java.util.ArrayList<>();
        addDeploymentInterval(intervals, workDate, start, end);
        addDeploymentInterval(intervals, workDate, afternoonStart, afternoonEnd);
        return intervals;
    }

    private static void addDeploymentInterval(
            List<DeploymentInterval> intervals, LocalDate workDate, LocalTime start, LocalTime end) {
        if (workDate == null || start == null || end == null || start.equals(end)) {
            return;
        }
        LocalDateTime intervalStart = workDate.atTime(start);
        LocalDateTime intervalEnd = workDate.atTime(end);
        if (!end.isAfter(start)) {
            intervalEnd = intervalEnd.plusDays(1);
        }
        intervals.add(new DeploymentInterval(intervalStart, intervalEnd));
    }

    private record DeploymentInterval(LocalDateTime start, LocalDateTime end) {
        private boolean overlaps(DeploymentInterval other) {
            return start.isBefore(other.end) && other.start.isBefore(end);
        }
    }

    /**
     * Trong ca: MORNING / AFTERNOON, hoặc FULL_DAY kèm giờ chiều riêng
     * (cộng giờ từng ca, không tính nghỉ trưa).
     * Ca thông tầm: một khung vào–ra nằm trong continuousDayStart–End.
     */
    private static boolean isInsideShiftDeployment(
            AttendanceWorkRequestSubmitDto dto,
            boolean continuous,
            AttendanceShiftSchedule schedule) {
        if (continuous) {
            if (dto.getRequestedAfternoonStart() != null || dto.getRequestedAfternoonEnd() != null) {
                return false;
            }
            return withinShift(
                    dto.getRequestedStart(),
                    dto.getRequestedEnd(),
                    schedule.continuousDayStart(),
                    schedule.continuousDayEnd());
        }
        if (dto.getShiftScope() == AttendanceShiftScope.MORNING
                || dto.getShiftScope() == AttendanceShiftScope.AFTERNOON) {
            return true;
        }
        return dto.getRequestedAfternoonStart() != null && dto.getRequestedAfternoonEnd() != null;
    }

    private boolean isInsideShiftDeploymentFromRequest(AttendanceWorkRequest req) {
        boolean continuous = continuousShiftService.isContinuousShift(
                req.getEmployee().getId(), req.getWorkDate());
        if (continuous) {
            if (req.getRequestedAfternoonStart() != null || req.getRequestedAfternoonEnd() != null) {
                return false;
            }
            AttendanceShiftSchedule schedule =
                    shiftScheduleService.forEmployee(req.getEmployee().getId(), req.getWorkDate());
            return withinShift(
                    req.getRequestedStart(),
                    req.getRequestedEnd(),
                    schedule.continuousDayStart(),
                    schedule.continuousDayEnd());
        }
        if (req.getShiftScope() == AttendanceShiftScope.MORNING
                || req.getShiftScope() == AttendanceShiftScope.AFTERNOON) {
            return true;
        }
        return req.getRequestedAfternoonStart() != null && req.getRequestedAfternoonEnd() != null;
    }

    private record InsideDeploymentUnits(BigDecimal morning, BigDecimal afternoon, String label) {}

    /**
     * Công trong ca tối đa sáng 1 / chiều 0,5; nếu chỉ làm một phần ca thì tỷ lệ theo giờ
     * (vd sáng 07:00–09:00 trong ca 07:00–11:30 → ~0,44 công).
     */
    private static BigDecimal prorateInsideUnits(
            LocalTime start,
            LocalTime end,
            LocalTime shiftStart,
            LocalTime shiftEnd,
            double shiftHours,
            BigDecimal fullUnits) {
        if (start == null || end == null || fullUnits == null || fullUnits.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO;
        }
        if (start.equals(shiftStart) && end.equals(shiftEnd)) {
            return fullUnits;
        }
        double hours = ChronoUnit.MINUTES.between(start, end) / 60.0;
        if (hours <= 0 || shiftHours <= 0) {
            return BigDecimal.ZERO;
        }
        double ratio = Math.min(1.0, hours / shiftHours);
        return fullUnits.multiply(BigDecimal.valueOf(ratio)).setScale(2, RoundingMode.HALF_UP);
    }

    private InsideDeploymentUnits resolveInsideDeploymentUnits(
            AttendanceWorkRequest req,
            AttendanceShiftSchedule schedule) {
        boolean continuous = continuousShiftService.isContinuousShift(
                req.getEmployee().getId(), req.getWorkDate());
        if (continuous) {
            double dayHours = schedule.continuousHours() > 0 ? schedule.continuousHours() : 8.0;
            BigDecimal fullDayBonus = DEPLOYMENT_INSIDE_MORNING_UNITS.add(DEPLOYMENT_INSIDE_AFTERNOON_UNITS);
            BigDecimal total = prorateInsideUnits(
                    req.getRequestedStart(),
                    req.getRequestedEnd(),
                    schedule.continuousDayStart(),
                    schedule.continuousDayEnd(),
                    dayHours,
                    fullDayBonus);
            // Giữ tỷ lệ 1.0 sáng / 0.5 chiều như ca thường để processor áp ×1,5
            BigDecimal morning = total.multiply(DEPLOYMENT_INSIDE_MORNING_UNITS)
                    .divide(fullDayBonus, 2, RoundingMode.HALF_UP);
            BigDecimal afternoon = total.subtract(morning).max(BigDecimal.ZERO);
            String label = String.format(
                    "Ca thông tầm %s–%s",
                    req.getRequestedStart(),
                    req.getRequestedEnd());
            return new InsideDeploymentUnits(morning, afternoon, label);
        }
        double morningHours = schedule.morningHours() > 0 ? schedule.morningHours() : 1;
        double afternoonHours = schedule.afternoonHours() > 0 ? schedule.afternoonHours() : 1;
        if (req.getRequestedAfternoonStart() != null && req.getRequestedAfternoonEnd() != null) {
            BigDecimal morning = prorateInsideUnits(
                    req.getRequestedStart(),
                    req.getRequestedEnd(),
                    schedule.morningStart(),
                    schedule.morningEnd(),
                    morningHours,
                    DEPLOYMENT_INSIDE_MORNING_UNITS);
            BigDecimal afternoon = prorateInsideUnits(
                    req.getRequestedAfternoonStart(),
                    req.getRequestedAfternoonEnd(),
                    schedule.afternoonStart(),
                    schedule.afternoonEnd(),
                    afternoonHours,
                    DEPLOYMENT_INSIDE_AFTERNOON_UNITS);
            String label = String.format(
                    "Cả ngày (%s–%s + %s–%s)",
                    req.getRequestedStart(),
                    req.getRequestedEnd(),
                    req.getRequestedAfternoonStart(),
                    req.getRequestedAfternoonEnd());
            return new InsideDeploymentUnits(morning, afternoon, label);
        }
        if (req.getShiftScope() == AttendanceShiftScope.MORNING) {
            BigDecimal morning = prorateInsideUnits(
                    req.getRequestedStart(),
                    req.getRequestedEnd(),
                    schedule.morningStart(),
                    schedule.morningEnd(),
                    morningHours,
                    DEPLOYMENT_INSIDE_MORNING_UNITS);
            return new InsideDeploymentUnits(
                    morning,
                    BigDecimal.ZERO,
                    String.format("Ca sáng %s–%s", req.getRequestedStart(), req.getRequestedEnd()));
        }
        if (req.getShiftScope() == AttendanceShiftScope.AFTERNOON) {
            BigDecimal afternoon = prorateInsideUnits(
                    req.getRequestedStart(),
                    req.getRequestedEnd(),
                    schedule.afternoonStart(),
                    schedule.afternoonEnd(),
                    afternoonHours,
                    DEPLOYMENT_INSIDE_AFTERNOON_UNITS);
            return new InsideDeploymentUnits(
                    BigDecimal.ZERO,
                    afternoon,
                    String.format("Ca chiều %s–%s", req.getRequestedStart(), req.getRequestedEnd()));
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
                    return "ABSENT".equals(st) || "LEAVE".equals(st) || "UNPAID_LEAVE".equals(st)
                            || "PERSONAL_LEAVE".equals(st)
                            || "BUSINESS_TRIP".equals(st) || "SEMINAR".equals(st);
                })
                .orElse(true);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> myRequests() {
        Employee emp = employeeService.linkedEmployee().orElse(null);
        if (emp == null) {
            return List.of();
        }
        FlowAssigneeCache cache = new FlowAssigneeCache();
        return requestRepository.findMineWithDetails(emp.getId()).stream()
                .map(r -> toMap(r, cache))
                .collect(Collectors.toList());
    }

    /** Hàng đợi chờ duyệt theo trạng thái — một cache người nhận cho cả danh sách. */
    private List<Map<String, Object>> pendingRows(Collection<AttendanceRequestStatus> statuses) {
        FlowAssigneeCache cache = new FlowAssigneeCache();
        return requestRepository.findPendingWithDetails(statuses).stream()
                .map(r -> toMap(r, cache))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> pendingForReviewer() {
        UserAccount user = employeeService.currentUser();
        if (ApprovalAuthority.isDirectorApprover(user) && user.getRole() != UserRole.ADMIN) {
            return pendingRows(PENDING_DIRECTOR);
        }
        if (user.getRole() == UserRole.HEAD_NURSING) {
            FlowAssigneeCache cache = new FlowAssigneeCache();
            return requestRepository.findPendingWithDetails(PENDING_NURSING_HEAD).stream()
                    .filter(r -> r.getRequestType() == AttendanceRequestType.DEPLOYMENT)
                    .filter(r -> NursingBlockClassifier.matchesNursingHeadScope(r.getEmployee()))
                    .map(r -> toMap(r, cache))
                    .collect(Collectors.toList());
        }
        if (user.getRole() == UserRole.HEAD_HR) {
            List<Map<String, Object>> headPending = filterPendingForHeadScope(
                    pendingRows(PENDING_HEAD),
                    user);
            List<Map<String, Object>> hrPending = requestRepository.findByStatusInOrderByCreatedAtAsc(PENDING_HR)
                    .stream()
                    .map(this::toMap)
                    .collect(Collectors.toList());
            return mergeRequestMaps(headPending, hrPending);
        }
        if (HEAD_ROLES.contains(user.getRole()) && !HR_APPROVER_ROLES.contains(user.getRole())) {
            return filterPendingForHeadScope(
                    pendingRows(PENDING_HEAD),
                    user);
        }
        if (EmployeeService.isHr2Role(user)) {
            return pendingRows(PENDING_HR);
        }
        // ADMIN: gộp tất cả hàng đợi đang chờ
        if (user.getRole() == UserRole.ADMIN) {
            EnumSet<AttendanceRequestStatus> all = EnumSet.of(
                    AttendanceRequestStatus.PENDING_HEAD,
                    AttendanceRequestStatus.PENDING_NURSING_HEAD,
                    AttendanceRequestStatus.PENDING_HR,
                    AttendanceRequestStatus.PENDING_DIRECTOR);
            return pendingRows(all);
        }
        if (HEAD_ROLES.contains(user.getRole())) {
            return filterPendingForHeadScope(
                    pendingRows(PENDING_HEAD),
                    user);
        }
        if (HR_APPROVER_ROLES.contains(user.getRole())) {
            return pendingRows(PENDING_HR);
        }
        if (DIRECTOR_ROLES.contains(user.getRole())) {
            return pendingRows(PENDING_DIRECTOR);
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền duyệt đơn công");
    }

    /**
     * Lịch sử duyệt. Không truyền ngày thì mặc định tháng hiện tại — giống web;
     * trước đây mobile không truyền ngày nên backend trả toàn bộ lịch sử từ
     * trước đến nay, mỗi dòng lại kéo theo hàng chục truy vấn.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> reviewHistoryForReviewer(LocalDate fromDate, LocalDate toDate) {
        UserAccount user = employeeService.currentUser();
        if (fromDate == null && toDate == null) {
            fromDate = LocalDate.now(VN_ZONE).withDayOfMonth(1);
        }
        Instant from = fromDate != null ? fromDate.atStartOfDay(VN_ZONE).toInstant() : Instant.EPOCH;
        Instant to = toDate != null
                ? toDate.plusDays(1).atStartOfDay(VN_ZONE).toInstant()
                : HISTORY_OPEN_END;
        FlowAssigneeCache cache = new FlowAssigneeCache();
        if (user.getRole() == UserRole.HEAD_NURSING) {
            return requestRepository.findHistoryWithDetails(NURSING_HEAD_HISTORY, from, to).stream()
                    .filter(r -> r.getRequestType() == AttendanceRequestType.DEPLOYMENT)
                    .filter(r -> NursingBlockClassifier.matchesNursingHeadScope(r.getEmployee()))
                    .filter(r -> r.getNursingHeadReviewedAt() != null
                            || r.getStatus() == AttendanceRequestStatus.NURSING_HEAD_REJECTED)
                    .map(r -> toMap(r, cache))
                    .collect(Collectors.toList());
        }
        EnumSet<AttendanceRequestStatus> statuses;
        if (user.getRole() == UserRole.ADMIN) {
            statuses = EnumSet.copyOf(HEAD_HISTORY);
            statuses.addAll(NURSING_HEAD_HISTORY);
            statuses.addAll(HR_HISTORY);
            statuses.addAll(DIRECTOR_HISTORY);
        } else if (user.getRole() == UserRole.HEAD_HR) {
            statuses = EnumSet.copyOf(HEAD_HISTORY);
            statuses.addAll(HR_HISTORY);
        } else if (ApprovalAuthority.isDirectorApprover(user)) {
            statuses = DIRECTOR_HISTORY;
        } else if (HEAD_ROLES.contains(user.getRole())) {
            statuses = HEAD_HISTORY;
        } else if (HR_APPROVER_ROLES.contains(user.getRole())) {
            statuses = HR_HISTORY;
        } else {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem lịch sử duyệt");
        }
        List<Map<String, Object>> rows = requestRepository.findHistoryWithDetails(statuses, from, to).stream()
                .map(r -> toMap(r, cache))
                .collect(Collectors.toList());
        if (user.getRole() == UserRole.HEAD_HR) {
            List<Map<String, Object>> headRows = filterPendingForHeadScope(
                    rows.stream()
                            .filter(r -> {
                                Object status = r.get("status");
                                return status != null && HEAD_HISTORY.stream()
                                        .anyMatch(s -> s.name().equals(String.valueOf(status)));
                            })
                            .collect(Collectors.toList()),
                    user);
            List<Map<String, Object>> hrRows = rows.stream()
                    .filter(r -> {
                        Object status = r.get("status");
                        return status != null && HR_HISTORY.stream()
                                .anyMatch(s -> s.name().equals(String.valueOf(status)));
                    })
                    .collect(Collectors.toList());
            return mergeRequestMaps(headRows, hrRows);
        }
        return HEAD_ROLES.contains(user.getRole()) && user.getRole() != UserRole.ADMIN
                ? filterPendingForHeadScope(rows, user)
                : rows;
    }

    /**
     * Danh sách đơn điều động theo ngày làm việc — phục vụ xuất Excel (HCNS2 / Trưởng HCNS / Admin).
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> listDeploymentsForExport(LocalDate fromDate, LocalDate toDate) {
        UserAccount user = employeeService.currentUser();
        if (!HR_APPROVER_ROLES.contains(user.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ HCNS được xuất danh sách điều động");
        }
        YearMonth ym = YearMonth.now();
        LocalDate from = fromDate != null ? fromDate : ym.atDay(1);
        LocalDate to = toDate != null ? toDate : ym.atEndOfMonth();
        if (to.isBefore(from)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
        }
        return requestRepository.findDeploymentsByWorkDateBetween(from, to).stream()
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    @Transactional
    public Map<String, Object> headReview(Long id, AttendanceReviewDto dto) {
        UserAccount reviewer = employeeService.currentUser();
        if (!HEAD_ROLES.contains(reviewer.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Ban giám đốc / Trưởng phòng duyệt bước 1");
        }
        AttendanceWorkRequest req = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy đơn"));
        boolean hasReachedHead = req.getStatus() == AttendanceRequestStatus.PENDING_HEAD
                || req.getHeadReviewedAt() != null;
        if (!hasReachedHead || req.getStatus() == AttendanceRequestStatus.WITHDRAWN) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn không thể thay đổi quyết định ở bước lãnh đạo");
        }
        AttendanceRequestStatus previousStatus = req.getStatus();
        employeeService.assertCanAccessEmployee(req.getEmployee());
        req.setHeadReviewer(reviewer);
        req.setHeadReviewedAt(Instant.now());
        req.setHeadComment(dto.getComment());
        req.setHeadSignaturePath(
                approvalSignatureService.snapshotForApproval(reviewer, "attendance", req.getId(), "head"));
        if (Boolean.FALSE.equals(dto.getApproved())) {
            if (isApprovedStatus(previousStatus)) {
                revokeAppliedAttendanceEffect(req);
            }
            req.setStatus(AttendanceRequestStatus.HEAD_REJECTED);
            requestRepository.save(req);
            notificationService.notifyAttendanceRequestResult(req.getEmployee().getUser(), req, false);
            return toMap(req);
        }
        if (previousStatus == AttendanceRequestStatus.PENDING_HEAD
                || previousStatus == AttendanceRequestStatus.HEAD_REJECTED) {
            if (req.getRequestType() == AttendanceRequestType.DEPLOYMENT
                    && NursingBlockClassifier.matchesNursingHeadScope(req.getEmployee())) {
                req.setStatus(AttendanceRequestStatus.PENDING_NURSING_HEAD);
            } else {
                req.setStatus(AttendanceRequestStatus.PENDING_HR);
            }
        }
        requestRepository.save(req);
        if (req.getStatus() == AttendanceRequestStatus.PENDING_NURSING_HEAD) {
            notifyNursingHeadNewRequest(req);
        } else if (req.getStatus() == AttendanceRequestStatus.PENDING_HR) {
            notifyHrNewRequest(req);
        }
        return toMap(req);
    }

    @Transactional
    public Map<String, Object> nursingHeadReview(Long id, AttendanceReviewDto dto) {
        UserAccount reviewer = employeeService.currentUser();
        if (!NURSING_HEAD_ROLES.contains(reviewer.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Trưởng phòng Điều dưỡng / ADMIN duyệt bước này");
        }
        AttendanceWorkRequest req = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy đơn"));
        if (req.getRequestType() != AttendanceRequestType.DEPLOYMENT) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Bước Trưởng phòng Điều dưỡng chỉ áp dụng cho đơn điều động");
        }
        boolean hasReachedNursingHead = req.getStatus() == AttendanceRequestStatus.PENDING_NURSING_HEAD
                || req.getNursingHeadReviewedAt() != null;
        if (!hasReachedNursingHead || req.getStatus() == AttendanceRequestStatus.WITHDRAWN) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn không thể thay đổi quyết định ở bước Trưởng phòng Điều dưỡng");
        }
        AttendanceRequestStatus previousStatus = req.getStatus();
        if (reviewer.getRole() == UserRole.HEAD_NURSING
                && !NursingBlockClassifier.matchesNursingHeadScope(req.getEmployee())) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ duyệt điều động nhân sự khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa");
        }
        employeeService.assertCanAccessEmployee(req.getEmployee());
        req.setNursingHeadReviewer(reviewer);
        req.setNursingHeadReviewedAt(Instant.now());
        req.setNursingHeadComment(dto.getComment());
        req.setNursingHeadSignaturePath(
                approvalSignatureService.snapshotForApproval(reviewer, "attendance", req.getId(), "nursing-head"));
        if (Boolean.FALSE.equals(dto.getApproved())) {
            if (isApprovedStatus(previousStatus)) {
                revokeAppliedAttendanceEffect(req);
            }
            req.setStatus(AttendanceRequestStatus.NURSING_HEAD_REJECTED);
            requestRepository.save(req);
            notificationService.notifyAttendanceRequestResult(req.getEmployee().getUser(), req, false);
            return toMap(req);
        }
        applyDeploymentTimeCorrection(req, dto);
        if (previousStatus == AttendanceRequestStatus.PENDING_NURSING_HEAD
                || previousStatus == AttendanceRequestStatus.NURSING_HEAD_REJECTED) {
            req.setStatus(AttendanceRequestStatus.PENDING_HR);
        }
        requestRepository.save(req);
        if (req.getStatus() == AttendanceRequestStatus.PENDING_HR) {
            notifyHrNewRequest(req);
        }
        return toMap(req);
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, AttendanceReviewDto dto) {
        UserAccount reviewer = employeeService.currentUser();
        if (!HR_APPROVER_ROLES.contains(reviewer.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ HCNS duyệt bước 2");
        }
        AttendanceWorkRequest req = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy đơn"));
        boolean hasReachedHr = req.getStatus() == AttendanceRequestStatus.PENDING_HR
                || req.getHrReviewedAt() != null;
        if (!hasReachedHr || req.getStatus() == AttendanceRequestStatus.WITHDRAWN) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn không thể thay đổi quyết định ở bước HCNS");
        }
        AttendanceRequestStatus previousStatus = req.getStatus();
        req.setHrReviewer(reviewer);
        req.setHrReviewedAt(Instant.now());
        req.setHrComment(dto.getComment());
        req.setHrSignaturePath(
                approvalSignatureService.snapshotForApproval(reviewer, "attendance", req.getId(), "hr"));
        if (Boolean.FALSE.equals(dto.getApproved())) {
            if (isApprovedStatus(previousStatus)) {
                revokeAppliedAttendanceEffect(req);
            }
            req.setStatus(AttendanceRequestStatus.HR_REJECTED);
            requestRepository.save(req);
            notificationService.notifyAttendanceRequestResult(req.getEmployee().getUser(), req, false);
            return toMap(req);
        }

        if (req.getRequestType() == AttendanceRequestType.DEPLOYMENT) {
            applyDeploymentTimeCorrection(req, dto);
        }

        // HCNS không quyết định phạt. Trừ / miễn tiền chỉ ở bước Giám đốc (directorReview).
        if (req.getRequestType() == AttendanceRequestType.UPDATE
                || req.getRequestType() == AttendanceRequestType.EXPLANATION
                || req.getRequestType() == AttendanceRequestType.LEAVE
                || req.getRequestType() == AttendanceRequestType.UNPAID_LEAVE
                || req.getRequestType() == AttendanceRequestType.PERSONAL_LEAVE
                || req.getRequestType() == AttendanceRequestType.DEPLOYMENT) {
            if (previousStatus == AttendanceRequestStatus.PENDING_HR
                    || previousStatus == AttendanceRequestStatus.HR_REJECTED) {
                req.setStatus(AttendanceRequestStatus.PENDING_DIRECTOR);
            }
            requestRepository.save(req);
            if (req.getStatus() == AttendanceRequestStatus.PENDING_DIRECTOR) {
                notifyDirectorNewRequest(req);
            }
            return toMap(req);
        }

        if (req.getRequestType() == AttendanceRequestType.BUSINESS_TRIP) {
            req.setStatus(AttendanceRequestStatus.APPROVED);
            if (previousStatus != AttendanceRequestStatus.APPROVED
                    && previousStatus != AttendanceRequestStatus.APPROVED_NO_FINE) {
                applyApprovedBusinessTrip(req);
            }
        } else {
            req.setStatus(AttendanceRequestStatus.APPROVED);
        }
        requestRepository.save(req);
        notificationService.notifyAttendanceRequestResult(req.getEmployee().getUser(), req, true);
        return toMap(req);
    }

    @Transactional
    public Map<String, Object> directorReview(Long id, AttendanceReviewDto dto) {
        UserAccount reviewer = employeeService.currentUser();
        if (!ApprovalAuthority.isDirectorApprover(reviewer)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Giám đốc duyệt bước cuối");
        }
        AttendanceWorkRequest req = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy đơn"));
        boolean hasReachedDirector = req.getStatus() == AttendanceRequestStatus.PENDING_DIRECTOR
                || req.getDirectorReviewedAt() != null;
        if (!hasReachedDirector || req.getStatus() == AttendanceRequestStatus.WITHDRAWN) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn không thể thay đổi quyết định ở bước Giám đốc");
        }
        AttendanceRequestStatus previousStatus = req.getStatus();
        if (req.getRequestType() != AttendanceRequestType.UPDATE
                && req.getRequestType() != AttendanceRequestType.EXPLANATION
                && req.getRequestType() != AttendanceRequestType.LEAVE
                && req.getRequestType() != AttendanceRequestType.UNPAID_LEAVE
                && req.getRequestType() != AttendanceRequestType.PERSONAL_LEAVE
                && req.getRequestType() != AttendanceRequestType.DEPLOYMENT) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Loại đơn này không cần Giám đốc duyệt");
        }
        req.setDirectorReviewer(reviewer);
        req.setDirectorReviewedAt(Instant.now());
        req.setDirectorComment(dto.getComment());
        req.setDirectorSignaturePath(
                approvalSignatureService.snapshotForApproval(reviewer, "attendance", req.getId(), "director"));
        if (Boolean.FALSE.equals(dto.getApproved())) {
            if (isApprovedStatus(previousStatus)) {
                revokeAppliedAttendanceEffect(req);
            }
            req.setStatus(AttendanceRequestStatus.DIRECTOR_REJECTED);
            requestRepository.save(req);
            notificationService.notifyAttendanceRequestResult(req.getEmployee().getUser(), req, false);
            return toMap(req);
        }
        boolean waive = Boolean.TRUE.equals(dto.getWaiveForgotFine());
        boolean keepOriginalPunchTimes = Boolean.TRUE.equals(dto.getKeepOriginalPunchTimes());
        if (req.getRequestType() == AttendanceRequestType.EXPLANATION && keepOriginalPunchTimes) {
            waive = true;
            req.setExplanationKeepOriginalTimes(true);
        } else if (req.getRequestType() == AttendanceRequestType.EXPLANATION) {
            req.setExplanationKeepOriginalTimes(false);
        }
        req.setHrWaiveForgotFine(waive);
        // UPDATE / EXPLANATION / nghỉ: ghi đè bảng công theo đơn (idempotent) — luôn áp lại khi duyệt.
        // Tránh bỏ qua vì note còn sót sau sync/thu hồi khiến trạng thái «đã duyệt» nhưng công trống.
        // DEPLOYMENT vẫn chỉ áp một lần (tránh cộng trùng OT).
        if (req.getRequestType() == AttendanceRequestType.UPDATE) {
            req.setStatus(waive ? AttendanceRequestStatus.APPROVED_NO_FINE : AttendanceRequestStatus.APPROVED);
            applyApprovedUpdate(req);
        } else if (req.getRequestType() == AttendanceRequestType.EXPLANATION) {
            req.setStatus(waive ? AttendanceRequestStatus.APPROVED_NO_FINE : AttendanceRequestStatus.APPROVED);
            applyApprovedExplanation(req, waive);
        } else if (req.getRequestType() == AttendanceRequestType.LEAVE) {
            req.setStatus(AttendanceRequestStatus.APPROVED);
            applyApprovedLeave(req);
        } else if (req.getRequestType() == AttendanceRequestType.UNPAID_LEAVE) {
            req.setStatus(AttendanceRequestStatus.APPROVED);
            applyApprovedUnpaidLeave(req);
        } else if (req.getRequestType() == AttendanceRequestType.PERSONAL_LEAVE) {
            req.setStatus(AttendanceRequestStatus.APPROVED);
            applyApprovedPersonalLeave(req);
        } else {
            req.setStatus(AttendanceRequestStatus.APPROVED);
            if (!attendanceEffectAlreadyApplied(req)) {
                applyApprovedDeployment(req);
            }
            if (req.getEmployee().getUser() != null) {
                notificationService.notifyStaffDeployment(
                        req.getEmployee().getUser(), req, "đã được Giám đốc phê duyệt");
            }
        }
        requestRepository.save(req);
        notificationService.notifyAttendanceRequestResult(req.getEmployee().getUser(), req, true);
        return toMap(req);
    }

    /** Trưởng phòng ĐD / HCNS chốt lại giờ điều động trước khi chuyển bước tiếp theo. */
    private void applyDeploymentTimeCorrection(
            AttendanceWorkRequest req, AttendanceReviewDto dto) {
        LocalTime start = dto.getRequestedStart() != null
                ? dto.getRequestedStart() : req.getRequestedStart();
        LocalTime end = dto.getRequestedEnd() != null
                ? dto.getRequestedEnd() : req.getRequestedEnd();
        if (start == null || end == null || start.equals(end)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Khung giờ điều động không hợp lệ");
        }

        boolean hasAfternoonRequest = dto.getRequestedAfternoonStart() != null
                || dto.getRequestedAfternoonEnd() != null
                || req.getRequestedAfternoonStart() != null
                || req.getRequestedAfternoonEnd() != null;
        LocalTime afternoonStart = dto.getRequestedAfternoonStart() != null
                ? dto.getRequestedAfternoonStart() : req.getRequestedAfternoonStart();
        LocalTime afternoonEnd = dto.getRequestedAfternoonEnd() != null
                ? dto.getRequestedAfternoonEnd() : req.getRequestedAfternoonEnd();
        if (hasAfternoonRequest
                && (afternoonStart == null || afternoonEnd == null || afternoonStart.equals(afternoonEnd))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Khung giờ điều động buổi chiều không hợp lệ");
        }

        req.setRequestedStart(start);
        req.setRequestedEnd(end);
        if (hasAfternoonRequest) {
            req.setRequestedAfternoonStart(afternoonStart);
            req.setRequestedAfternoonEnd(afternoonEnd);
        }
    }

    private static final EnumSet<AttendanceRequestStatus> APPROVED_EFFECT_STATUSES = EnumSet.of(
            AttendanceRequestStatus.APPROVED,
            AttendanceRequestStatus.APPROVED_NO_FINE);

    /**
     * Sau đồng bộ máy chấm công: áp lại hiệu lực đơn đã duyệt (giải trình / cập nhật công / nghỉ…).
     * Đơn vẫn còn trong DB; chỉ bảng công bị ghi đè bởi dữ liệu máy.
     */
    @Transactional
    public int reapplyApprovedEffectsAfterPunchSync(
            LocalDate from, LocalDate to, Collection<Long> employeeIds) {
        if (from == null || to == null || to.isBefore(from)) {
            return 0;
        }
        List<AttendanceWorkRequest> requests;
        if (employeeIds == null || employeeIds.isEmpty()) {
            requests = requestRepository.findApprovedOverlapping(from, to, APPROVED_EFFECT_STATUSES);
        } else {
            requests = requestRepository.findApprovedOverlappingForEmployees(
                    from, to, employeeIds, APPROVED_EFFECT_STATUSES);
        }
        return forceReapplyApproved(requests);
    }

    /**
     * Phép ghi nhận ngoài hệ thống (admin gắn): chỉ đánh dấu LEAVE lên các ngày chưa có dữ liệu
     * chấm công, không ghi đè ngày đã có giờ vào/ra. Trả về số ngày đã đánh dấu.
     */
    @Transactional
    public int applyManualLeaveOnEmptyDays(AttendanceWorkRequest req) {
        LocalDate from = req.getWorkDate();
        LocalDate to = req.getEndDate() != null ? req.getEndDate() : from;
        int marked = 0;
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            if (isOffOrEmptyWorkDay(req.getEmployee().getId(), d)) {
                applyLeaveDay(req.getEmployee(), d, req.getReason());
                marked++;
            }
        }
        return marked;
    }

    /**
     * Gỡ hiệu lực phép ghi nhận ngoài hệ thống: các ngày đang là LEAVE (không có giờ chấm) trở về
     * ABSENT 0 công; ngày đã có dữ liệu chấm công giữ nguyên.
     */
    @Transactional
    public int revertManualLeaveDays(AttendanceWorkRequest req) {
        LocalDate from = req.getWorkDate();
        LocalDate to = req.getEndDate() != null ? req.getEndDate() : from;
        int reverted = 0;
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            AttendanceRecord rec = attendanceRecordRepository
                    .findByEmployeeAndWorkDate(req.getEmployee(), d).orElse(null);
            if (rec == null || !"LEAVE".equals(rec.getStatus())) {
                continue;
            }
            // Tính lại từ log máy chấm công gốc (nếu có) — giống thu hồi đơn nghỉ thường
            rec.setStatus("ABSENT");
            rec.setLateMinutesExempt(false);
            rec.setOvertimeWorkUnits(BigDecimal.ZERO);
            String note = stripProtectedDayNotes(rec.getNote());
            rec.setNote(note.isBlank() ? null : note);
            dayProcessor.applyToRecord(rec);
            attendanceRecordRepository.save(rec);
            reverted++;
        }
        return reverted;
    }

    /**
     * Đơn nghỉ (phép / không lương / chế độ) còn hiệu lực hoặc đang chờ duyệt giao với khoảng ngày.
     */
    public List<AttendanceWorkRequest> findLeaveConflicts(Long employeeId, LocalDate from, LocalDate to) {
        EnumSet<AttendanceRequestStatus> live = EnumSet.of(
                AttendanceRequestStatus.PENDING_HEAD,
                AttendanceRequestStatus.PENDING_NURSING_HEAD,
                AttendanceRequestStatus.PENDING_HR,
                AttendanceRequestStatus.PENDING_DIRECTOR,
                AttendanceRequestStatus.APPROVED,
                AttendanceRequestStatus.APPROVED_NO_FINE);
        return requestRepository.findApprovedOverlappingForEmployees(from, to, List.of(employeeId), live).stream()
                .filter(r -> isRangedLeaveType(r.getRequestType()))
                .toList();
    }

    public Map<String, Object> leaveBalanceSnapshot(Employee emp, int year) {
        return leaveBalanceFor(emp, year);
    }

    /**
     * Khôi phục hiệu lực mọi đơn công đã duyệt trong khoảng ngày (ADMIN/HR).
     * Dùng khi đồng bộ trước đó đã ghi đè bảng công.
     */
    @Transactional
    public Map<String, Object> reapplyApprovedEffectsInRange(LocalDate from, LocalDate to) {
        if (from == null || to == null || to.isBefore(from)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Khoảng ngày không hợp lệ");
        }
        int reapplied = reapplyApprovedEffectsAfterPunchSync(from, to, null);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("from", from.toString());
        result.put("to", to.toString());
        result.put("reapplied", reapplied);
        return result;
    }

    private int forceReapplyApproved(List<AttendanceWorkRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return 0;
        }
        List<AttendanceWorkRequest> ordered = requests.stream()
                .sorted(java.util.Comparator
                        .comparingInt((AttendanceWorkRequest r) -> reapplyPriority(r.getRequestType()))
                        .thenComparing(AttendanceWorkRequest::getWorkDate)
                        .thenComparing(AttendanceWorkRequest::getId))
                .toList();
        int ok = 0;
        for (AttendanceWorkRequest req : ordered) {
            try {
                forceReapplyOne(req);
                ok++;
            } catch (Exception e) {
                // Không chặn cả batch — đơn lỗi ghi log để xử lý riêng
                log.warn("Không áp lại đơn công id={} type={}: {}",
                        req.getId(), req.getRequestType(), e.getMessage());
            }
        }
        return ok;
    }

    private static int reapplyPriority(AttendanceRequestType type) {
        return switch (type) {
            case LEAVE, UNPAID_LEAVE, PERSONAL_LEAVE, BUSINESS_TRIP -> 0;
            case UPDATE -> 1;
            case EXPLANATION -> 2;
            case DEPLOYMENT -> 3;
        };
    }

    private void forceReapplyOne(AttendanceWorkRequest req) {
        boolean waive = req.isHrWaiveForgotFine()
                || req.getStatus() == AttendanceRequestStatus.APPROVED_NO_FINE;
        switch (req.getRequestType()) {
            case UPDATE -> applyApprovedUpdate(req);
            case EXPLANATION -> applyApprovedExplanation(req, waive);
            case LEAVE -> applyApprovedLeave(req);
            case UNPAID_LEAVE -> applyApprovedUnpaidLeave(req);
            case PERSONAL_LEAVE -> applyApprovedPersonalLeave(req);
            case BUSINESS_TRIP -> applyApprovedBusinessTrip(req);
            case DEPLOYMENT -> {
                // OT/điều động trong ca đã được applyToRecord đọc lại từ ghi chú [DD:…] / [DDTC:…]
                // Chỉ áp lại khi marker đã mất (tránh cộng trùng công).
                if (!attendanceEffectAlreadyApplied(req)) {
                    applyApprovedDeployment(req);
                }
            }
        }
    }

    /**
     * Khi sửa quyết định nhiều lần, không cộng lại công/giờ đã được áp dụng ở lần duyệt trước.
     * Trạng thái đơn có thể đã đổi sang từ chối, vì vậy cần nhận biết bằng dấu vết trên bảng công.
     */
    private boolean attendanceEffectAlreadyApplied(AttendanceWorkRequest req) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(req.getEmployee(), req.getWorkDate())
                .orElse(null);
        if (rec == null) {
            return false;
        }
        String note = rec.getNote() != null ? rec.getNote() : "";
        return switch (req.getRequestType()) {
            case UPDATE -> note.contains("Cập nhật công theo đơn đã duyệt");
            case EXPLANATION -> note.contains("Giải trình đã duyệt");
            case LEAVE -> "LEAVE".equals(rec.getStatus()) || note.contains("Nghỉ phép đã duyệt");
            case UNPAID_LEAVE -> "UNPAID_LEAVE".equals(rec.getStatus())
                    || note.contains("Nghỉ không lương đã duyệt");
            case PERSONAL_LEAVE -> "PERSONAL_LEAVE".equals(rec.getStatus())
                    || note.contains("Nghỉ chế độ");
            case BUSINESS_TRIP -> "BUSINESS_TRIP".equals(rec.getStatus())
                    || note.contains("Công tác đã duyệt");
            case DEPLOYMENT -> req.getId() != null && note.contains("[DD:" + req.getId() + "]");
        };
    }

    private static boolean isApprovedStatus(AttendanceRequestStatus status) {
        return status == AttendanceRequestStatus.APPROVED
                || status == AttendanceRequestStatus.APPROVED_NO_FINE;
    }

    /** Bỏ phần công đã áp dụng khi cấp duyệt đổi quyết định từ duyệt sang không duyệt. */
    private void revokeAppliedAttendanceEffect(AttendanceWorkRequest req) {
        LocalDate to = req.getEndDate() != null ? req.getEndDate() : req.getWorkDate();
        for (LocalDate date = req.getWorkDate(); !date.isAfter(to); date = date.plusDays(1)) {
            AttendanceRecord rec = attendanceRecordRepository
                    .findByEmployeeAndWorkDate(req.getEmployee(), date)
                    .orElse(null);
            if (rec == null) {
                continue;
            }

            List<LocalTime> punches = new java.util.ArrayList<>(dayProcessor.resolvePunches(rec));
            if (req.getRequestType() == AttendanceRequestType.UPDATE) {
                boolean continuous = continuousShiftService.isContinuousShift(
                        req.getEmployee().getId(), date);
                if (continuous) {
                    // Giữ giờ vào máy; chỉ gỡ mốc ra đã bổ sung từ đơn (tránh mất 6h07 khi thu hồi)
                    punches.remove(req.getRequestedEnd());
                    punches.remove(req.getRequestedAfternoonEnd());
                } else {
                    punches.remove(req.getRequestedStart());
                    punches.remove(req.getRequestedEnd());
                    punches.remove(req.getRequestedAfternoonStart());
                    punches.remove(req.getRequestedAfternoonEnd());
                }
            } else if (req.getRequestType() == AttendanceRequestType.EXPLANATION) {
                punches.remove(req.getExplainedTime());
                punches.remove(req.getExplainedDepartureTime());
                punches.remove(req.getExplainedMorningIn());
                punches.remove(req.getExplainedMorningOut());
                punches.remove(req.getExplainedAfternoonIn());
                punches.remove(req.getExplainedAfternoonOut());
            }

            rec.setPunchTimesJson(dayProcessor.writePunches(punches.stream().distinct().sorted().toList()));
            rec.setStatus("ABSENT");
            rec.setLateMinutesExempt(false);
            rec.setOvertimeWorkUnits(java.math.BigDecimal.ZERO);
            rec.setNote(req.getRequestType() == AttendanceRequestType.DEPLOYMENT
                    ? removeDeploymentNote(rec.getNote(), req.getId())
                    : stripProtectedDayNotes(rec.getNote()));
            dayProcessor.applyToRecord(rec);
            attendanceRecordRepository.save(rec);
        }
    }

    @Transactional
    public Map<String, Object> withdraw(Long id) {
        UserAccount actor = employeeService.currentUser();
        AttendanceWorkRequest req = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy đơn"));
        if (actor.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Đơn đã gửi không thể thu hồi. Liên hệ quản trị viên nếu cần xử lý.");
        }
        boolean pending = req.getStatus() == AttendanceRequestStatus.PENDING_HEAD
                || req.getStatus() == AttendanceRequestStatus.PENDING_NURSING_HEAD
                || req.getStatus() == AttendanceRequestStatus.PENDING_HR
                || req.getStatus() == AttendanceRequestStatus.PENDING_DIRECTOR;
        if (req.getStatus() == AttendanceRequestStatus.WITHDRAWN) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn đã thu hồi rồi");
        }
        AttendanceRequestStatus previous = req.getStatus();
        // ADMIN: mọi trạng thái (đã duyệt / từ chối / chờ) đều thu hồi được — gỡ hiệu lực công nếu đã áp dụng
        if (!pending) {
            revokeAppliedAttendanceEffect(req);
        }
        req.setStatus(AttendanceRequestStatus.WITHDRAWN);
        requestRepository.save(req);
        notificationService.notifyAttendanceRequestWithdrawn(req, previous);
        return toMap(req);
    }

    private void applyApprovedExplanation(AttendanceWorkRequest req, boolean waiveLateFine) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(req.getEmployee(), req.getWorkDate())
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(req.getEmployee())
                        .workDate(req.getWorkDate())
                        .status("ABSENT")
                        .build());

        boolean keepOriginalTimes = req.isExplanationKeepOriginalTimes();
        if (!keepOriginalTimes) {
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
        } else {
            dayProcessor.applyToRecord(rec);
            dayProcessor.applyProportionalWorkUnitsFromPunches(rec);
        }

        if (waiveLateFine || keepOriginalTimes) {
            rec.setLateMinutesExempt(true);
            rec.setLateMinutes(0);
            if (keepOriginalTimes) {
                rec.setNote(appendNote(rec.getNote(),
                        "Giải trình đã duyệt — giữ giờ chấm gốc, Giám đốc miễn phạt muộn/sớm"));
            } else {
                rec.setNote(appendNote(rec.getNote(), "Giải trình đã duyệt — Giám đốc miễn phạt muộn/sớm"));
            }
        } else {
            rec.setNote(appendNote(rec.getNote(), "Giải trình đã duyệt — tính phạt theo giờ giải trình"));
        }
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
        boolean continuous = continuousShiftService.isContinuousShift(
                req.getEmployee().getId(), req.getWorkDate());
        boolean twoPunch = continuousShiftService.isTwoPunchAttendance(req.getEmployee().getId());
        if (continuous) {
            LocalTime dayIn = req.getRequestedStart();
            LocalTime dayOut = req.getRequestedAfternoonEnd() != null
                    ? req.getRequestedAfternoonEnd()
                    : req.getRequestedEnd();
            dayProcessor.applyManualShift(rec, AttendanceShiftScope.FULL_DAY, dayIn, dayOut);
        } else if (twoPunch && req.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT) {
            LocalTime dayIn = req.getRequestedStart();
            LocalTime dayOut = req.getRequestedAfternoonEnd() != null
                    ? req.getRequestedAfternoonEnd()
                    : req.getRequestedEnd();
            dayProcessor.applyManualFullDay(rec, dayIn, null, null, dayOut);
        } else if (req.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT) {
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

    private void applyApprovedUnpaidLeave(AttendanceWorkRequest req) {
        LocalDate from = req.getWorkDate();
        LocalDate to = req.getEndDate() != null ? req.getEndDate() : from;
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            applyUnpaidLeaveDay(req.getEmployee(), d, req.getReason());
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
                .findByEmployeeAndWorkDateForUpdate(req.getEmployee(), req.getWorkDate())
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(req.getEmployee())
                        .workDate(req.getWorkDate())
                        .status("ABSENT")
                        .morningWorkUnits(BigDecimal.ZERO)
                        .afternoonWorkUnits(BigDecimal.ZERO)
                        .overtimeWorkUnits(BigDecimal.ZERO)
                        .build());
        AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(req.getEmployee().getId(), req.getWorkDate());
        boolean continuous = continuousShiftService.isContinuousShift(
                req.getEmployee().getId(), req.getWorkDate());
        boolean insideShift = isInsideShiftDeploymentFromRequest(req);
        double dayHours = continuous
                ? (schedule.continuousHours() > 0 ? schedule.continuousHours() : 8.0)
                : (schedule.totalHours() > 0 ? schedule.totalHours() : 8.0);

        BigDecimal morningBonus = BigDecimal.ZERO;
        BigDecimal afternoonBonus = BigDecimal.ZERO;
        BigDecimal overtimeBonus = BigDecimal.ZERO;
        double actualHours;
        String timeLabel;

        if (insideShift) {
            InsideDeploymentUnits inside = resolveInsideDeploymentUnits(req, schedule);
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

        if (insideShift) {
            String morningWindow;
            String afternoonWindow;
            if (continuous) {
                morningWindow = start + "-" + end;
                afternoonWindow = "-";
            } else {
                morningWindow = req.getShiftScope() == AttendanceShiftScope.AFTERNOON
                        ? "-"
                        : start + "-" + end;
                if (req.getRequestedAfternoonStart() != null && req.getRequestedAfternoonEnd() != null) {
                    afternoonWindow = req.getRequestedAfternoonStart() + "-" + req.getRequestedAfternoonEnd();
                } else if (req.getShiftScope() == AttendanceShiftScope.AFTERNOON) {
                    afternoonWindow = start + "-" + end;
                } else {
                    afternoonWindow = "-";
                }
            }
            String noteLine = String.format(
                    continuous
                            ? "Điều động trong ca thông tầm ×%.1f: %s — chờ đủ giờ vào/ra "
                                    + "(=%s sáng / =%s chiều / +0 ngoài giờ) [DDTC:S=%s;A=%s]"
                            : "Điều động trong ca ×%.1f: %s — chờ đủ giờ vào/ra "
                                    + "(=%s sáng / =%s chiều / +0 ngoài giờ) [DDTC:S=%s;A=%s]",
                    DEPLOYMENT_COEFFICIENT.doubleValue(),
                    timeLabel,
                    morningBonus.toPlainString(),
                    afternoonBonus.toPlainString(),
                    morningWindow,
                    afternoonWindow);
            if (req.getReason() != null && !req.getReason().isBlank()) {
                noteLine += ": " + req.getReason().trim();
            }
            rec.setLateMinutesExempt(false);
            rec.setNote(appendNote(stripProtectedDayNotesKeepingDeployments(rec.getNote()),
                    deploymentNoteWithId(noteLine, req.getId())));
            // Đơn duyệt chỉ xác nhận khung điều động. Công được tính bởi bộ xử lý ngày
            // khi dữ liệu máy chấm công có đủ cặp vào/ra tương ứng.
            dayProcessor.applyToRecord(rec);
            attendanceRecordRepository.save(rec);
            return;
        }

        double creditedHours = actualHours * DEPLOYMENT_COEFFICIENT.doubleValue();
        boolean replaceShiftUnits = false;

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
        rec.setNote(appendNote(stripProtectedDayNotesKeepingDeployments(rec.getNote()),
                deploymentNoteWithId(noteLine, req.getId())));
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

    /**
     * Ngày nghỉ / công tác đã duyệt: xoá giờ vào-ra hiển thị nhưng GIỮ log máy chấm công gốc trong
     * punchTimesJson — khi thu hồi / từ chối đơn, {@code revokeAppliedAttendanceEffect} tính lại được
     * giờ vào/ra và trạng thái mà không cần đồng bộ lại máy chấm công.
     */
    private void preserveRawPunches(AttendanceRecord rec) {
        if (rec.getPunchTimesJson() == null || rec.getPunchTimesJson().isBlank()) {
            rec.setPunchTimesJson(dayProcessor.writePunches(dayProcessor.resolvePunches(rec)));
        }
    }

    private void applyLeaveDay(Employee emp, LocalDate workDate, String reason) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, workDate)
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(emp)
                        .workDate(workDate)
                        .status("ABSENT")
                        .build());
        AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(emp.getId(), workDate);
        preserveRawPunches(rec);
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

    /**
     * Nghỉ chế độ: chính thức hưởng lương cơ bản (đủ công ca, trạng thái PERSONAL_LEAVE,
     * không trừ phép năm); thử việc / thực tập khoá ngày 0 công như nghỉ không lương.
     */
    private void applyApprovedPersonalLeave(AttendanceWorkRequest req) {
        LocalDate from = req.getWorkDate();
        LocalDate to = req.getEndDate() != null ? req.getEndDate() : from;
        boolean paid = Boolean.TRUE.equals(req.getPersonalLeavePaid());
        String kindLabel = req.getPersonalLeaveKind() != null ? req.getPersonalLeaveKind().label() : "chế độ";
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            applyPersonalLeaveDay(req.getEmployee(), d, req.getReason(), kindLabel, paid);
        }
    }

    private void applyPersonalLeaveDay(
            Employee emp, LocalDate workDate, String reason, String kindLabel, boolean paid) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, workDate)
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(emp)
                        .workDate(workDate)
                        .status("ABSENT")
                        .build());
        preserveRawPunches(rec);
        rec.setCheckIn(null);
        rec.setCheckOut(null);
        rec.setMorningCheckIn(null);
        rec.setMorningCheckOut(null);
        rec.setAfternoonCheckIn(null);
        rec.setAfternoonCheckOut(null);
        if (paid) {
            AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(emp.getId(), workDate);
            rec.setMorningWorkUnits(schedule.morningUnits());
            rec.setAfternoonWorkUnits(schedule.afternoonUnits());
            rec.setStatus("PERSONAL_LEAVE");
        } else {
            rec.setMorningWorkUnits(BigDecimal.ZERO);
            rec.setAfternoonWorkUnits(BigDecimal.ZERO);
            rec.setStatus("UNPAID_LEAVE");
        }
        rec.setOvertimeWorkUnits(BigDecimal.ZERO);
        rec.setLateMinutes(0);
        rec.setLateMinutesExempt(true);
        rec.setForgotShifts(null);
        String noteLine = "Nghỉ chế độ (" + kindLabel + ") đã duyệt"
                + (paid ? " — hưởng lương cơ bản" : " — thử việc, không lương");
        if (reason != null && !reason.isBlank()) {
            noteLine += ": " + reason.trim();
        }
        rec.setNote(appendNote(stripProtectedDayNotes(rec.getNote()), noteLine));
        attendanceRecordRepository.save(rec);
    }

    /** Nghỉ không lương: khóa ngày, 0 công — không tính vào tổng công / lương. */
    private void applyUnpaidLeaveDay(Employee emp, LocalDate workDate, String reason) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, workDate)
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(emp)
                        .workDate(workDate)
                        .status("ABSENT")
                        .build());
        preserveRawPunches(rec);
        rec.setCheckIn(null);
        rec.setCheckOut(null);
        rec.setMorningCheckIn(null);
        rec.setMorningCheckOut(null);
        rec.setAfternoonCheckIn(null);
        rec.setAfternoonCheckOut(null);
        rec.setMorningWorkUnits(BigDecimal.ZERO);
        rec.setAfternoonWorkUnits(BigDecimal.ZERO);
        rec.setOvertimeWorkUnits(BigDecimal.ZERO);
        rec.setLateMinutes(0);
        rec.setLateMinutesExempt(true);
        rec.setForgotShifts(null);
        rec.setStatus("UNPAID_LEAVE");
        String noteLine = "Nghỉ không lương đã duyệt";
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
        AttendanceShiftSchedule schedule = shiftScheduleService.forEmployee(emp.getId(), workDate);
        preserveRawPunches(rec);
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
        return stripProtectedDayNotes(existing, false);
    }

    private static String stripProtectedDayNotesKeepingDeployments(String existing) {
        return stripProtectedDayNotes(existing, true);
    }

    private static String stripProtectedDayNotes(String existing, boolean keepDeployments) {
        if (existing == null || existing.isBlank()) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (String part : existing.split(";")) {
            String p = part.trim();
            if (p.isEmpty()
                    || p.startsWith("Nghỉ phép đã duyệt")
                    || p.startsWith("Nghỉ không lương đã duyệt")
                    || p.startsWith("Nghỉ chế độ")
                    || p.startsWith("Công tác đã duyệt")
                    || p.startsWith("Hội thảo đã duyệt")
                    || p.startsWith("Cập nhật công theo đơn đã duyệt")
                    || p.startsWith("Giải trình đã duyệt")
                    || (!keepDeployments && p.startsWith("Điều động"))
                    // Giữ điều động chỉ khi đã gắn mã đơn duyệt [DD:] / [DDTC:]
                    || (keepDeployments && p.startsWith("Điều động")
                        && !AttendanceDayProcessor.isApprovedDeploymentNoteSegment(p))) {
                continue;
            }
            if (sb.length() > 0) {
                sb.append("; ");
            }
            sb.append(p);
        }
        return sb.toString();
    }

    private static String deploymentNoteWithId(String noteLine, Long requestId) {
        return requestId == null ? noteLine : noteLine + " [DD:" + requestId + "]";
    }

    private static String removeDeploymentNote(String existing, Long requestId) {
        if (existing == null || existing.isBlank() || requestId == null) {
            return stripProtectedDayNotes(existing);
        }
        String marker = "[DD:" + requestId + "]";
        int markerIndex = existing.indexOf(marker);
        if (markerIndex < 0) {
            return stripProtectedDayNotes(existing);
        }
        int lineStart = existing.lastIndexOf("Điều động", markerIndex);
        if (lineStart < 0) {
            return stripProtectedDayNotes(existing);
        }
        int lineEnd = markerIndex + marker.length();
        if (lineEnd < existing.length() && existing.charAt(lineEnd) == ';') {
            lineEnd++;
        }
        while (lineEnd < existing.length() && existing.charAt(lineEnd) == ' ') {
            lineEnd++;
        }
        String before = existing.substring(0, lineStart).replaceFirst(";\\s*$", "");
        return (before + existing.substring(lineEnd)).trim();
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

    private void validateSubmit(AttendanceWorkRequestSubmitDto dto, Employee emp, Long excludeId) {
        if (dto.getRequestType() == AttendanceRequestType.UPDATE) {
            if (dto.getUpdateKind() == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn cập nhật cần chọn loại ca");
            }
            if (dto.getRequestedStart() == null || dto.getRequestedEnd() == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập thời gian bắt đầu và kết thúc");
            }
            boolean continuous = continuousShiftService.isContinuousShift(emp.getId(), dto.getWorkDate());
            boolean twoPunch = continuousShiftService.isTwoPunchAttendance(emp.getId());
            if (continuous) {
                if (!dto.getRequestedStart().isBefore(dto.getRequestedEnd())) {
                    throw new ApiException(HttpStatus.BAD_REQUEST,
                            "Ca thông tầm: giờ vào phải trước giờ ra");
                }
            } else if (twoPunch) {
                if (!dto.getRequestedStart().isBefore(dto.getRequestedEnd())) {
                    throw new ApiException(HttpStatus.BAD_REQUEST,
                            "Phân quyền công: giờ vào sáng phải trước giờ ra chiều");
                }
            } else if (dto.getUpdateKind() == AttendanceUpdateKind.FULL_DAY_SUPPLEMENT
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
            if (excludeId != null) {
                remaining += requestRepository.findById(excludeId)
                        .filter(r -> r.getRequestType() == AttendanceRequestType.LEAVE)
                        .filter(r -> r.getStatus() == AttendanceRequestStatus.PENDING_HEAD
                                || r.getStatus() == AttendanceRequestStatus.PENDING_NURSING_HEAD
                                || r.getStatus() == AttendanceRequestStatus.PENDING_HR
                                || r.getStatus() == AttendanceRequestStatus.PENDING_DIRECTOR)
                        .map(r -> {
                            LocalDate oldFrom = r.getWorkDate();
                            LocalDate oldTo = r.getEndDate() != null ? r.getEndDate() : oldFrom;
                            return LeaveEntitlement.calendarDaysInclusive(oldFrom, oldTo);
                        })
                        .orElse(0);
            }
            if (requestDays > remaining) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        String.format(
                                "Vượt hạn mức phép năm %d: còn %d ngày, đơn xin %d ngày (tối đa %d ngày/năm).",
                                dto.getWorkDate().getYear(),
                                remaining,
                                requestDays,
                                bal.get("entitlementDays")));
            }
            assertMonthlyWorkAllowsPaidLeave(emp, dto.getWorkDate(), end, excludeId);
            assertNoOverlappingLeaveKinds(emp.getId(), dto.getWorkDate(), end, excludeId);
        } else if (dto.getRequestType() == AttendanceRequestType.UNPAID_LEAVE) {
            LocalDate end = dto.getEndDate() != null ? dto.getEndDate() : dto.getWorkDate();
            if (end.isBefore(dto.getWorkDate())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
            }
            assertNoOverlappingLeaveKinds(emp.getId(), dto.getWorkDate(), end, excludeId);
        } else if (dto.getRequestType() == AttendanceRequestType.PERSONAL_LEAVE) {
            if (dto.getPersonalLeaveKind() == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Cần chọn chế độ nghỉ: NLĐ kết hôn hoặc người thân NLĐ mất");
            }
            LocalDate end = dto.getEndDate() != null ? dto.getEndDate() : dto.getWorkDate();
            if (end.isBefore(dto.getWorkDate())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
            }
            int requestDays = LeaveEntitlement.calendarDaysInclusive(dto.getWorkDate(), end);
            if (requestDays > PERSONAL_LEAVE_MAX_DAYS) {
                throw new ApiException(HttpStatus.BAD_REQUEST, String.format(
                        "Nghỉ chế độ tối đa %d ngày, đơn xin %d ngày", PERSONAL_LEAVE_MAX_DAYS, requestDays));
            }
            assertNoOverlappingLeaveKinds(emp.getId(), dto.getWorkDate(), end, excludeId);
        } else if (dto.getRequestType() == AttendanceRequestType.BUSINESS_TRIP) {
            LocalDate end = dto.getEndDate() != null ? dto.getEndDate() : dto.getWorkDate();
            if (end.isBefore(dto.getWorkDate())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
            }
            if (dto.getLocation() == null || dto.getLocation().isBlank()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập địa điểm công tác");
            }
            assertNoOverlappingRangedRequest(emp.getId(), AttendanceRequestType.BUSINESS_TRIP, dto.getWorkDate(), end,
                    "Khoảng ngày trùng với đơn công tác khác (đang chờ hoặc đã duyệt)", excludeId);
        } else {
            List<AttendanceWorkRequest> existing = requestRepository.findByEmployeeIdAndWorkDateAndRequestType(
                    emp.getId(), dto.getWorkDate(), dto.getRequestType());
            boolean open = existing.stream()
                    .filter(r -> excludeId == null || !r.getId().equals(excludeId))
                    .anyMatch(r ->
                    r.getStatus() == AttendanceRequestStatus.PENDING_HEAD
                            || r.getStatus() == AttendanceRequestStatus.PENDING_NURSING_HEAD
                            || r.getStatus() == AttendanceRequestStatus.PENDING_HR
                            || r.getStatus() == AttendanceRequestStatus.PENDING_DIRECTOR);
            if (open) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Đã có đơn đang chờ duyệt cho ngày này");
            }
        }
    }

    private void assertNoOverlappingLeaveKinds(Long employeeId, LocalDate from, LocalDate to, Long excludeId) {
        EnumSet<AttendanceRequestStatus> blocking = EnumSet.of(
                AttendanceRequestStatus.PENDING_HEAD,
                AttendanceRequestStatus.PENDING_NURSING_HEAD,
                AttendanceRequestStatus.PENDING_HR,
                AttendanceRequestStatus.PENDING_DIRECTOR,
                AttendanceRequestStatus.APPROVED);
        List<AttendanceWorkRequest> ranged = requestRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .filter(r -> excludeId == null || !r.getId().equals(excludeId))
                .filter(r -> r.getRequestType() == AttendanceRequestType.LEAVE
                        || r.getRequestType() == AttendanceRequestType.UNPAID_LEAVE
                        || r.getRequestType() == AttendanceRequestType.PERSONAL_LEAVE)
                .filter(r -> blocking.contains(r.getStatus()))
                .toList();
        for (AttendanceWorkRequest r : ranged) {
            LocalDate rFrom = r.getWorkDate();
            LocalDate rTo = r.getEndDate() != null ? r.getEndDate() : rFrom;
            boolean overlap = !from.isAfter(rTo) && !to.isBefore(rFrom);
            if (overlap) {
                String kind = switch (r.getRequestType()) {
                    case UNPAID_LEAVE -> "nghỉ không lương";
                    case PERSONAL_LEAVE -> "nghỉ chế độ";
                    default -> "nghỉ phép";
                };
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Khoảng ngày trùng với đơn " + kind + " khác (đang chờ hoặc đã duyệt)");
            }
        }
    }

    private void assertNoOverlappingRangedRequest(
            Long employeeId,
            AttendanceRequestType type,
            LocalDate from,
            LocalDate to,
            String message,
            Long excludeId) {
        EnumSet<AttendanceRequestStatus> blocking = EnumSet.of(
                AttendanceRequestStatus.PENDING_HEAD,
                AttendanceRequestStatus.PENDING_NURSING_HEAD,
                AttendanceRequestStatus.PENDING_HR,
                AttendanceRequestStatus.PENDING_DIRECTOR,
                AttendanceRequestStatus.APPROVED);
        List<AttendanceWorkRequest> ranged = requestRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .filter(r -> excludeId == null || !r.getId().equals(excludeId))
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
        // ADMIN / HCNS / Giám đốc: xem mọi NV. Các role khác: chỉ bản thân (hoặc trong phạm vi quản lý).
        if (current.getRole() != UserRole.ADMIN
                && current.getRole() != UserRole.HR
                && !EmployeeService.isHr2Role(current)
                && !com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(current)) {
            Employee self = employeeLinkService.findLinkedEmployee(current).orElse(null);
            if (self != null && self.getId().equals(emp.getId())) {
                // bản thân
            } else if (EmployeeService.isHeadRole(current)
                    || current.getRole() == UserRole.HEAD_NURSING) {
                employeeService.assertCanAccessEmployee(emp);
            } else {
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
        // Thử việc / thực tập hoặc chưa có thâm niên → tối thiểu 12 ngày phép/năm
        int entitlement = Math.max(LeaveEntitlement.BASE_DAYS, LeaveEntitlement.entitlementDays(emp.getHireDate(), asOf));
        int years = LeaveEntitlement.yearsOfService(emp.getHireDate(), asOf);

        EnumSet<AttendanceRequestStatus> usedStatuses = EnumSet.of(AttendanceRequestStatus.APPROVED);
        EnumSet<AttendanceRequestStatus> pendingStatuses = EnumSet.of(
                AttendanceRequestStatus.PENDING_HEAD,
                AttendanceRequestStatus.PENDING_NURSING_HEAD,
                AttendanceRequestStatus.PENDING_HR,
                AttendanceRequestStatus.PENDING_DIRECTOR);

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

    private void assertMonthlyWorkAllowsPaidLeave(Employee emp, LocalDate from, LocalDate to, Long excludeId) {
        EnumSet<AttendanceRequestStatus> pendingStatuses = EnumSet.of(
                AttendanceRequestStatus.PENDING_HEAD,
                AttendanceRequestStatus.PENDING_NURSING_HEAD,
                AttendanceRequestStatus.PENDING_HR,
                AttendanceRequestStatus.PENDING_DIRECTOR);
        YearMonth cursor = YearMonth.from(from);
        YearMonth last = YearMonth.from(to);
        while (!cursor.isAfter(last)) {
            LocalDate monthStart = cursor.atDay(1);
            LocalDate monthEnd = cursor.atEndOfMonth();
            int newDays = LeaveEntitlement.overlapDays(from, to, monthStart, monthEnd);
            if (newDays > 0) {
                BigDecimal recorded = monthWorkExcludingDeployment(emp, cursor);
                int pendingDays = sumLeaveDays(emp.getId(), monthStart, monthEnd, pendingStatuses, excludeId);
                if (LeaveEntitlement.exceedsMonthlyWorkCap(recorded, pendingDays + newDays)) {
                    BigDecimal used = recorded.add(BigDecimal.valueOf(pendingDays));
                    throw new ApiException(HttpStatus.BAD_REQUEST, monthlyLeaveCapMessage(cursor, used, newDays));
                }
            }
            cursor = cursor.plusMonths(1);
        }
    }

    private BigDecimal monthWorkExcludingDeployment(Employee emp, YearMonth ym) {
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.atEndOfMonth();
        BigDecimal shift = BigDecimal.ZERO;
        for (AttendanceRecord rec : attendanceRecordRepository
                .findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to)) {
            shift = shift.add(nzUnits(rec.getMorningWorkUnits())).add(nzUnits(rec.getAfternoonWorkUnits()));
        }
        Map<String, Object> duty = dutyShiftService.rollup(
                emp, dutyShiftService.findEntriesForEmployee(emp.getId(), from, to));
        return shift.add((BigDecimal) duty.get("dutyWorkUnitsTotal"));
    }

    private static String monthlyLeaveCapMessage(YearMonth ym, BigDecimal used, int requestDays) {
        BigDecimal cap = LeaveEntitlement.MONTHLY_WORK_CAP_EXCLUDING_DEPLOYMENT;
        BigDecimal remain = cap.subtract(used);
        int remainDays = remain.signum() <= 0 ? 0 : remain.setScale(0, RoundingMode.FLOOR).intValue();
        String usedLabel = used.stripTrailingZeros().toPlainString().replace('.', ',');
        if (remainDays <= 0) {
            return String.format(
                    "Tháng %02d/%d đã đủ %s công (chấm + phép + trực, chưa gồm điều động). "
                            + "Đủ %s công thì không được tạo đơn nghỉ phép.",
                    ym.getMonthValue(), ym.getYear(), usedLabel, cap.toPlainString());
        }
        return String.format(
                "Tháng %02d/%d đã có %s công (chưa gồm điều động, hạn mức %s công). "
                        + "Đơn xin %d ngày nhưng chỉ còn xin được tối đa %d ngày phép.",
                ym.getMonthValue(), ym.getYear(), usedLabel, cap.toPlainString(), requestDays, remainDays);
    }

    private static BigDecimal nzUnits(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }

    private int sumLeaveDays(
            Long employeeId, LocalDate yearStart, LocalDate yearEnd, EnumSet<AttendanceRequestStatus> statuses) {
        return sumLeaveDays(employeeId, yearStart, yearEnd, statuses, null);
    }

    private int sumLeaveDays(
            Long employeeId,
            LocalDate yearStart,
            LocalDate yearEnd,
            EnumSet<AttendanceRequestStatus> statuses,
            Long excludeId) {
        return requestRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .filter(r -> excludeId == null || !excludeId.equals(r.getId()))
                .filter(r -> r.getRequestType() == AttendanceRequestType.LEAVE)
                .filter(r -> statuses.contains(r.getStatus()))
                .mapToInt(r -> {
                    LocalDate from = r.getWorkDate();
                    LocalDate to = r.getEndDate() != null ? r.getEndDate() : from;
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
        return employeeService.requireLinkedEmployee();
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
        userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_HR))
                .stream()
                .filter(u -> employeeService.shouldReceiveHeadPendingNotification(u, req.getEmployee()))
                .forEach(u -> notificationService.notifyAttendanceRequestPending(u, req, "HEAD"));
    }

    private void notifyNursingHeadNewRequest(AttendanceWorkRequest req) {
        userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HEAD_NURSING))
                .stream()
                .filter(u -> employeeService.shouldReceiveNursingHeadPendingNotification(u, req.getEmployee()))
                .forEach(u -> notificationService.notifyAttendanceRequestPending(u, req, "NURSING_HEAD"));
    }

    private void notifyHrNewRequest(AttendanceWorkRequest req) {
        userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HR2, UserRole.HEAD_HR))
                .forEach(u -> notificationService.notifyAttendanceRequestPending(u, req, "HR"));
    }

    private void notifyDirectorNewRequest(AttendanceWorkRequest req) {
        userAccountRepository.findByDirectorApprovalEnabledTrueAndEnabledTrue()
                .forEach(u -> notificationService.notifyAttendanceRequestPending(u, req, "DIRECTOR"));
    }

    /**
     * Trưởng khoa/phòng chỉ thấy đơn của nhân viên trong khoa/phòng mình.
     * Trưởng bộ phận (workUnitScoped) bị giới hạn tiếp theo đúng bộ phận.
     */
    private List<Map<String, Object>> filterPendingForHeadScope(
            List<Map<String, Object>> rows, UserAccount user) {
        if (!EmployeeService.isHeadRole(user)) {
            return rows;
        }
        return rows.stream()
                .filter(row -> {
                    Object rawId = row.get("employeeId");
                    if (!(rawId instanceof Number n)) {
                        return false;
                    }
                    Employee emp = employeeRepository.findById(n.longValue()).orElse(null);
                    if (emp == null) {
                        return false;
                    }
                    return employeeService.matchesHeadScope(user, emp);
                })
                .collect(Collectors.toList());
    }

    private List<Map<String, Object>> mergeRequestMaps(
            List<Map<String, Object>> first, List<Map<String, Object>> second) {
        Map<Object, Map<String, Object>> byId = new LinkedHashMap<>();
        if (first != null) {
            for (Map<String, Object> row : first) {
                if (row != null && row.get("id") != null) {
                    byId.put(row.get("id"), row);
                }
            }
        }
        if (second != null) {
            for (Map<String, Object> row : second) {
                if (row != null && row.get("id") != null) {
                    byId.putIfAbsent(row.get("id"), row);
                }
            }
        }
        return new ArrayList<>(byId.values());
    }

    private Map<String, Object> toMap(AttendanceWorkRequest r) {
        return toMap(r, new FlowAssigneeCache());
    }

    /**
     * @param cache người nhận từng bước duyệt, dùng chung cho cả danh sách để
     *              không tải lại bảng tài khoản cho mỗi dòng.
     */
    private Map<String, Object> toMap(AttendanceWorkRequest r, FlowAssigneeCache cache) {
        Map<String, Object> m = new LinkedHashMap<>();
        // Hai cờ này tốn 2-3 truy vấn; tính đúng một lần và chỉ khi loại đơn cần.
        boolean needsShiftFlags = r.getRequestType() == AttendanceRequestType.UPDATE
                || r.getRequestType() == AttendanceRequestType.EXPLANATION
                || r.getRequestType() == AttendanceRequestType.DEPLOYMENT;
        boolean continuousShift = needsShiftFlags
                && continuousShiftService.isContinuousShift(r.getEmployee().getId(), r.getWorkDate());
        boolean twoPunch = needsShiftFlags
                && continuousShiftService.isTwoPunchAttendance(r.getEmployee().getId());
        m.put("id", r.getId());
        m.put("employeeId", r.getEmployee().getId());
        m.put("employeeCode", r.getEmployee().getEmployeeCode());
        m.put("employeeName", r.getEmployee().getFullName());
        m.put("positionTitle", r.getEmployee().getPosition() != null
                ? r.getEmployee().getPosition().getTitle() : null);
        m.put("department", r.getEmployee().getDepartment().getName());
        m.put("requestType", r.getRequestType().name());
        m.put("workDate", r.getWorkDate().toString());
        m.put("endDate", r.getEndDate() != null ? r.getEndDate().toString() : "");
        int rangedDays = isRangedLeaveType(r.getRequestType())
                ? LeaveEntitlement.calendarDaysInclusive(
                        r.getWorkDate(), r.getEndDate() != null ? r.getEndDate() : r.getWorkDate())
                : 0;
        m.put("leaveDays", (r.getRequestType() == AttendanceRequestType.LEAVE
                || r.getRequestType() == AttendanceRequestType.UNPAID_LEAVE
                || r.getRequestType() == AttendanceRequestType.PERSONAL_LEAVE) ? rangedDays : 0);
        m.put("personalLeaveKind", r.getPersonalLeaveKind() != null ? r.getPersonalLeaveKind().name() : null);
        m.put("personalLeaveKindLabel", r.getPersonalLeaveKind() != null ? r.getPersonalLeaveKind().label() : null);
        m.put("personalLeavePaid", r.getPersonalLeavePaid());
        m.put("tripDays", r.getRequestType() == AttendanceRequestType.BUSINESS_TRIP ? rangedDays : 0);
        m.put("shiftScope", r.getShiftScope().name());
        m.put("updateKind", r.getUpdateKind() != null ? r.getUpdateKind().name() : "");
        if (needsShiftFlags) {
            m.put("continuousShift", continuousShift);
            m.put("twoPunchAttendance", twoPunch);
        }
        m.put("reason", r.getReason());
        m.put("location", r.getLocation() != null ? r.getLocation() : "");
        m.put("requestedStart", r.getRequestedStart() != null ? r.getRequestedStart().toString() : "");
        m.put("requestedEnd", r.getRequestedEnd() != null ? r.getRequestedEnd().toString() : "");
        if (r.getRequestType() == AttendanceRequestType.DEPLOYMENT
                || r.getRequestType() == AttendanceRequestType.UPDATE
                || r.getRequestType() == AttendanceRequestType.EXPLANATION) {
            List<String> attendancePunchTimes = attendanceRecordRepository
                    .findByEmployeeAndWorkDate(r.getEmployee(), r.getWorkDate())
                    .map(dayProcessor::resolvePunches)
                    .orElseGet(List::of)
                    .stream()
                    .sorted()
                    .distinct()
                    .map(time -> time.toString().substring(0, 5))
                    .toList();
            m.put("attendancePunchTimes", attendancePunchTimes);
        }
        if (r.getRequestType() == AttendanceRequestType.DEPLOYMENT
                && r.getRequestedStart() != null && r.getRequestedEnd() != null) {
            m.put("deploymentCoefficient", DEPLOYMENT_COEFFICIENT.doubleValue());
            if (isInsideShiftDeploymentFromRequest(r)) {
                AttendanceShiftSchedule sch = shiftScheduleService.forEmployee(r.getEmployee().getId(), r.getWorkDate());
                InsideDeploymentUnits inside = resolveInsideDeploymentUnits(r, sch);
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
        LocalTime origMIn = r.getOriginalMorningIn();
        LocalTime origMOut = r.getOriginalMorningOut();
        LocalTime origAIn = r.getOriginalAfternoonIn();
        LocalTime origAOut = r.getOriginalAfternoonOut();
        // Đơn cũ chưa snapshot: lấy giờ máy hiện tại nếu phiếu vẫn đang chờ duyệt
        boolean pendingExplanation = r.getRequestType() == AttendanceRequestType.EXPLANATION
                && r.getStatus() != null
                && r.getStatus().name().startsWith("PENDING_");
        boolean needOriginal = pendingExplanation && (
                (origMIn == null && r.getExplainedMorningIn() != null)
                        || (origMOut == null && r.getExplainedMorningOut() != null)
                        || (origAIn == null && r.getExplainedAfternoonIn() != null)
                        || (origAOut == null && r.getExplainedAfternoonOut() != null)
                        || (origMIn == null && r.getExplainedTime() != null
                        && r.getExplanationKind() != ExplanationKind.EARLY_DEPARTURE)
                        || (origAOut == null && (r.getExplainedDepartureTime() != null
                        || (r.getExplainedTime() != null
                        && r.getExplanationKind() == ExplanationKind.EARLY_DEPARTURE))));
        if (needOriginal) {
            AttendanceRecord rec = attendanceRecordRepository
                    .findByEmployeeAndWorkDate(r.getEmployee(), r.getWorkDate())
                    .orElse(null);
            if (rec != null) {
                LocalTime morningIn = rec.getMorningCheckIn() != null ? rec.getMorningCheckIn() : rec.getCheckIn();
                LocalTime afternoonOut = rec.getAfternoonCheckOut() != null
                        ? rec.getAfternoonCheckOut() : rec.getCheckOut();
                if (origMIn == null && (r.getExplainedMorningIn() != null
                        || (r.getExplainedTime() != null
                        && r.getExplanationKind() != ExplanationKind.EARLY_DEPARTURE))) {
                    origMIn = morningIn;
                }
                if (origMOut == null && r.getExplainedMorningOut() != null) {
                    origMOut = rec.getMorningCheckOut();
                }
                if (origAIn == null && r.getExplainedAfternoonIn() != null) {
                    origAIn = rec.getAfternoonCheckIn();
                }
                if (origAOut == null && (r.getExplainedAfternoonOut() != null
                        || r.getExplainedDepartureTime() != null
                        || (r.getExplainedTime() != null
                        && r.getExplanationKind() == ExplanationKind.EARLY_DEPARTURE))) {
                    origAOut = afternoonOut;
                }
            }
        }
        m.put("originalMorningIn", origMIn != null ? origMIn.toString() : "");
        m.put("originalMorningOut", origMOut != null ? origMOut.toString() : "");
        m.put("originalAfternoonIn", origAIn != null ? origAIn.toString() : "");
        m.put("originalAfternoonOut", origAOut != null ? origAOut.toString() : "");
        m.put("status", r.getStatus().name());
        m.put("headComment", r.getHeadComment() != null ? r.getHeadComment() : "");
        m.put("nursingHeadComment", r.getNursingHeadComment() != null ? r.getNursingHeadComment() : "");
        m.put("hrComment", r.getHrComment() != null ? r.getHrComment() : "");
        m.put("directorComment", r.getDirectorComment() != null ? r.getDirectorComment() : "");
        m.put("headSignatureUrl", r.getHeadSignaturePath() != null && !r.getHeadSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/attendance/" + r.getId() + "/head" : null);
        m.put("nursingHeadSignatureUrl",
                r.getNursingHeadSignaturePath() != null && !r.getNursingHeadSignaturePath().isBlank()
                        ? "/j1-api/v1/approval-signatures/attendance/" + r.getId() + "/nursing-head" : null);
        m.put("hrSignatureUrl", r.getHrSignaturePath() != null && !r.getHrSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/attendance/" + r.getId() + "/hr" : null);
        m.put("directorSignatureUrl", r.getDirectorSignaturePath() != null && !r.getDirectorSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/attendance/" + r.getId() + "/director" : null);
        m.put("headReviewedAt", r.getHeadReviewedAt() != null ? r.getHeadReviewedAt().toString() : "");
        m.put("nursingHeadReviewedAt",
                r.getNursingHeadReviewedAt() != null ? r.getNursingHeadReviewedAt().toString() : "");
        m.put("headReviewerUsername",
                r.getHeadReviewer() != null ? r.getHeadReviewer().getUsername() : null);
        m.put("headReviewerName", accountPersonName(r.getHeadReviewer()));
        m.put("nursingHeadReviewerUsername",
                r.getNursingHeadReviewer() != null ? r.getNursingHeadReviewer().getUsername() : null);
        m.put("nursingHeadReviewerName", accountPersonName(r.getNursingHeadReviewer()));
        m.put("hrReviewerUsername",
                r.getHrReviewer() != null ? r.getHrReviewer().getUsername() : null);
        m.put("hrReviewerName", accountPersonName(r.getHrReviewer()));
        m.put("directorReviewerUsername",
                r.getDirectorReviewer() != null ? r.getDirectorReviewer().getUsername() : null);
        m.put("directorReviewerName", accountPersonName(r.getDirectorReviewer()));
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : "");
        m.put("directorReviewedAt", r.getDirectorReviewedAt() != null ? r.getDirectorReviewedAt().toString() : "");
        m.put("hrWaiveForgotFine", r.isHrWaiveForgotFine());
        m.put("explanationKeepOriginalTimes", r.isExplanationKeepOriginalTimes());
        putFlowAssigneeNames(m, r, cache);
        if (r.getRequestType() == AttendanceRequestType.UPDATE) {
            boolean continuousOrTwoPunch = continuousShift || twoPunch;
            int units = AttendancePenaltyCalculator.forgotFineUnitsForWorkRequest(r, continuousOrTwoPunch);
            // Đơn đang chờ: tính lại theo bảng công hiện tại (tránh hiện 2 lần khi đã có giờ vào)
            if (continuousOrTwoPunch && !isApprovedStatus(r.getStatus())
                    && r.getStatus() != AttendanceRequestStatus.WITHDRAWN
                    && r.getUpdateKind() != null) {
                AttendanceRecord existing = attendanceRecordRepository
                        .findByEmployeeAndWorkDate(r.getEmployee(), r.getWorkDate())
                        .orElse(null);
                int recomputed = AttendancePenaltyCalculator.forgotFineUnitsForUpdate(
                        r.getUpdateKind(), existing, true);
                if (recomputed > 0) {
                    units = recomputed;
                }
            }
            m.put("forgotFineUnits", units);
        }
        m.put("createdAt", r.getCreatedAt().toString());
        m.put("requestedByUsername", resolveRequestedByUsername(r));
        return m;
    }

    private String resolveRequestedByUsername(AttendanceWorkRequest r) {
        if (r.getRequestType() == AttendanceRequestType.DEPLOYMENT && r.getHeadReviewer() != null) {
            return r.getHeadReviewer().getUsername();
        }
        Employee emp = r.getEmployee();
        if (emp.getUser() != null) {
            return emp.getUser().getUsername();
        }
        return null;
    }

    /** Tên người nhận / đã duyệt từng bước — ưu tiên người đã ký, không thì người đang được gửi tới. */
    private void putFlowAssigneeNames(Map<String, Object> m, AttendanceWorkRequest r, FlowAssigneeCache cache) {
        Employee emp = r.getEmployee();
        m.put("flowSubmitterName", emp.getFullName());
        // Chỉ tra danh sách người nhận khi bước đó chưa có người ký. Bản cũ dùng
        // firstNonBlank(a, b) nên b luôn được tính dù a đã có — mỗi dòng đơn kéo
        // theo bốn lượt tải bảng tài khoản kèm kiểm tra phạm vi từng người.
        m.put("flowHeadName", firstNonBlankLazy(
                accountPersonName(r.getHeadReviewer()),
                () -> joinPersonNames(cache.headAssignees(emp))));
        m.put("flowNursingHeadName", firstNonBlankLazy(
                accountPersonName(r.getNursingHeadReviewer()),
                () -> joinPersonNames(cache.nursingHeadAssignees(emp))));
        m.put("flowHrName", firstNonBlankLazy(
                accountPersonName(r.getHrReviewer()),
                () -> joinPersonNames(cache.hrAssignees())));
        m.put("flowDirectorName", firstNonBlankLazy(
                accountPersonName(r.getDirectorReviewer()),
                () -> joinPersonNames(cache.directorAssignees())));
    }

    private static String firstNonBlankLazy(String first, Supplier<String> fallback) {
        if (first != null && !first.isBlank()) {
            return first.trim();
        }
        String value = fallback.get();
        return value != null && !value.isBlank() ? value.trim() : null;
    }

    /**
     * Cache người nhận từng bước duyệt trong một lượt trả danh sách.
     *
     * Bảng tài khoản theo vai trò chỉ tải một lần; riêng bước Trưởng khoa và
     * Trưởng phòng ĐD còn phụ thuộc phạm vi nhân viên nên nhớ theo phòng ban.
     */
    private final class FlowAssigneeCache {
        private List<UserAccount> headAccounts;
        private List<UserAccount> nursingHeadAccounts;
        private List<UserAccount> hrAccounts;
        private List<UserAccount> directorAccounts;
        private final Map<Long, List<UserAccount>> headByDepartment = new HashMap<>();
        private final Map<Long, List<UserAccount>> nursingHeadByDepartment = new HashMap<>();

        List<UserAccount> headAssignees(Employee emp) {
            if (headAccounts == null) {
                headAccounts = userAccountRepository
                        .findByRoleIn(List.of(UserRole.HEAD_DEPARTMENT, UserRole.HEAD_HR)).stream()
                        .filter(UserAccount::isEnabled)
                        .toList();
            }
            Long key = emp.getDepartment() != null ? emp.getDepartment().getId() : -1L;
            return headByDepartment.computeIfAbsent(key, k -> headAccounts.stream()
                    .filter(u -> employeeService.shouldReceiveHeadPendingNotification(u, emp))
                    .toList());
        }

        List<UserAccount> nursingHeadAssignees(Employee emp) {
            if (nursingHeadAccounts == null) {
                nursingHeadAccounts = userAccountRepository
                        .findByRoleIn(List.of(UserRole.HEAD_NURSING)).stream()
                        .filter(UserAccount::isEnabled)
                        .toList();
            }
            Long key = emp.getDepartment() != null ? emp.getDepartment().getId() : -1L;
            return nursingHeadByDepartment.computeIfAbsent(key, k -> nursingHeadAccounts.stream()
                    .filter(u -> employeeService.shouldReceiveNursingHeadPendingNotification(u, emp))
                    .toList());
        }

        List<UserAccount> hrAssignees() {
            if (hrAccounts == null) {
                hrAccounts = userAccountRepository
                        .findByRoleIn(List.of(UserRole.HR2, UserRole.HEAD_HR)).stream()
                        .filter(UserAccount::isEnabled)
                        .toList();
            }
            return hrAccounts;
        }

        List<UserAccount> directorAssignees() {
            if (directorAccounts == null) {
                directorAccounts = userAccountRepository.findByDirectorApprovalEnabledTrueAndEnabledTrue();
            }
            return directorAccounts;
        }
    }

    private static String joinPersonNames(List<UserAccount> users) {
        if (users == null || users.isEmpty()) {
            return null;
        }
        String joined = users.stream()
                .map(AttendanceWorkRequestService::accountPersonName)
                .filter(n -> n != null && !n.isBlank())
                .distinct()
                .collect(Collectors.joining(", "));
        return joined.isBlank() ? null : joined;
    }

    private static String accountPersonName(UserAccount u) {
        if (u == null) {
            return null;
        }
        try {
            Employee linked = u.getEmployee();
            if (linked != null && linked.getFullName() != null && !linked.getFullName().isBlank()) {
                return linked.getFullName().trim();
            }
        } catch (Exception ignored) {
            // lazy load có thể fail ngoài session — fallback displayName/username
        }
        if (u.getDisplayName() != null && !u.getDisplayName().isBlank()) {
            return u.getDisplayName().trim();
        }
        return u.getUsername();
    }

}
