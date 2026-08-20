package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceDayProcessor;
import com.minhan.hrm.dto.seminar.SeminarProposalCreateRequest;
import com.minhan.hrm.dto.seminar.SeminarProposalReviewRequest;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.SeminarProposalRequestRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.service.support.RequestEditSupport;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class SeminarProposalService {

    private static final Set<SeminarProposalStatus> BLOCKING_OVERLAP = Set.of(
            SeminarProposalStatus.PENDING_HR,
            SeminarProposalStatus.PENDING_DIRECTOR,
            SeminarProposalStatus.APPROVED);
    private static final DateTimeFormatter VN_DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");

    private final SeminarProposalRequestRepository proposalRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeLinkService employeeLinkService;
    private final UserAccountRepository userAccountRepository;
    private final AttendanceRecordRepository attendanceRecordRepository;
    private final AttendanceDayProcessor attendanceDayProcessor;
    private final EmployeeService employeeService;
    private final NotificationService notificationService;
    private final ApprovalSignatureService approvalSignatureService;

    @Transactional
    public Map<String, Object> create(SeminarProposalCreateRequest req) {
        UserAccount actor = ensureHeadOrAdmin();
        Employee emp = employeeRepository.findById(req.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (emp.getStatus() == EmployeeStatus.TERMINATED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đề xuất hội thảo cho nhân viên đã nghỉ việc");
        }
        assertNoOverlappingSeminarProposal(emp.getId(), req.getStartDate(), req.getEndDate(), null);
        if (req.getEndDate().isBefore(req.getStartDate())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
        }
        if (!req.getStartDate().equals(req.getEndDate())
                && req.getAttendanceScope() != AttendanceShiftScope.FULL_DAY) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn hội thảo nhiều ngày phải áp dụng cả ngày");
        }
        if (!Boolean.TRUE.equals(req.getEmployeeCommitmentAck())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần xác nhận cam kết của nhân viên được cử đi hội thảo");
        }
        if (!Boolean.TRUE.equals(req.getDepartmentCommitmentAck())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần xác nhận cam kết của Khoa/Phòng đề xuất");
        }

        SeminarProposalRequest row = SeminarProposalRequest.builder()
                .employee(emp)
                .proposingDepartment(req.getProposingDepartment().trim())
                .seminarName(req.getSeminarName().trim())
                .location(req.getLocation().trim())
                .startDate(req.getStartDate())
                .endDate(req.getEndDate())
                .attendanceScope(req.getAttendanceScope())
                .reason(req.getReason().trim())
                .employeeCommitmentAck(true)
                .departmentCommitmentAck(true)
                .status(SeminarProposalStatus.PENDING_DIRECTOR)
                .requestedBy(actor)
                .build();
        row = proposalRepository.save(row);

        notifyDirectorsPending(row);
        notificationService.notifySeminarProposalSubmittedToEmployee(row);
        notificationService.notifySeminarProposalForwardedToDirector(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> update(Long id, SeminarProposalCreateRequest req) {
        UserAccount actor = employeeService.currentUser();
        SeminarProposalRequest row = proposalRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất hội thảo"));
        RequestEditSupport.ensureRequesterOrAdmin(actor, row.getRequestedBy(),
                "Không có quyền chỉnh sửa phiếu này");
        RequestEditSupport.ensurePendingStatus(row.getStatus(), "phiếu hội thảo");

        Employee emp = row.getEmployee();
        if (!emp.getId().equals(req.getEmployeeId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đổi nhân viên khi chỉnh sửa phiếu");
        }
        if (emp.getStatus() == EmployeeStatus.TERMINATED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đề xuất hội thảo cho nhân viên đã nghỉ việc");
        }
        assertNoOverlappingSeminarProposal(emp.getId(), req.getStartDate(), req.getEndDate(), id);
        if (req.getEndDate().isBefore(req.getStartDate())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc phải sau hoặc bằng ngày bắt đầu");
        }
        if (!req.getStartDate().equals(req.getEndDate())
                && req.getAttendanceScope() != AttendanceShiftScope.FULL_DAY) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn hội thảo nhiều ngày phải áp dụng cả ngày");
        }
        if (!Boolean.TRUE.equals(req.getEmployeeCommitmentAck())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần xác nhận cam kết của nhân viên được cử đi hội thảo");
        }
        if (!Boolean.TRUE.equals(req.getDepartmentCommitmentAck())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần xác nhận cam kết của Khoa/Phòng đề xuất");
        }

        row.setProposingDepartment(req.getProposingDepartment().trim());
        row.setSeminarName(req.getSeminarName().trim());
        row.setLocation(req.getLocation().trim());
        row.setStartDate(req.getStartDate());
        row.setEndDate(req.getEndDate());
        row.setAttendanceScope(req.getAttendanceScope());
        row.setReason(req.getReason().trim());
        row.setEmployeeCommitmentAck(true);
        row.setDepartmentCommitmentAck(true);
        row = proposalRepository.save(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingHr() {
        UserAccount actor = ensureCanView();
        return proposalRepository.findPendingWithDetails(SeminarProposalStatus.PENDING_HR).stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingDirector() {
        UserAccount actor = ensureCanView();
        return proposalRepository.findPendingWithDetails(SeminarProposalStatus.PENDING_DIRECTOR).stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listReviewHistory() {
        UserAccount actor = ensureCanView();
        return proposalRepository.findReviewHistoryWithDetails().stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listMine() {
        UserAccount actor = employeeService.currentUser();
        return proposalRepository.findByRequestedBy_IdOrderByCreatedAtDesc(actor.getId()).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listByEmployee(Long employeeId) {
        ensureCanListForEmployee(employeeId);
        return proposalRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listRelatedToMe() {
        Employee self = requireSelfEmployee();
        return proposalRepository.findByEmployeeIdOrderByCreatedAtDesc(self.getId()).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getById(Long id) {
        SeminarProposalRequest row = proposalRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất hội thảo"));
        ensureCanViewDetail(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, SeminarProposalReviewRequest body) {
        throw new ApiException(HttpStatus.GONE,
                "Quy trình mới bỏ bước HCNS — phiếu hội thảo gửi thẳng Giám đốc duyệt");
    }

    @Transactional
    public Map<String, Object> directorReview(Long id, SeminarProposalReviewRequest body) {
        UserAccount director = ensureDirectorOrAdmin();
        SeminarProposalRequest row = proposalRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất hội thảo"));
        if (row.getStatus() != SeminarProposalStatus.PENDING_DIRECTOR
                && row.getStatus() != SeminarProposalStatus.DIRECTOR_REJECTED
                && row.getStatus() != SeminarProposalStatus.APPROVED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Phiếu đã hoàn thành hoặc đã hủy nên không thể đổi quyết định");
        }
        SeminarProposalStatus previousStatus = row.getStatus();
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setDirectorReviewer(director);
        row.setDirectorReviewedAt(Instant.now());
        row.setDirectorComment(blankToNull(body.getComment()));
        row.setDirectorSignaturePath(
                approvalSignatureService.snapshotForApproval(director, "seminar", row.getId(), "director"));

        if (!approved) {
            if (previousStatus == SeminarProposalStatus.APPROVED) {
                revokeSeminarDays(row);
            }
            // Khi đổi quyết định từ duyệt sang từ chối, không được giữ nhãn
            // "Có công/Không công" và tiền hỗ trợ của quyết định cũ.
            row.setWithPay(null);
            row.setSupportAmount(null);
            row.setStatus(SeminarProposalStatus.DIRECTOR_REJECTED);
            proposalRepository.save(row);
            notificationService.notifySeminarProposalResult(row, false, "Giám đốc");
            return toMap(row);
        }

        if (body.getWithPay() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Khi duyệt cần chọn có công hoặc không công");
        }
        row.setWithPay(Boolean.TRUE.equals(body.getWithPay()));
        row.setSupportAmount(blankToNull(body.getSupportAmount()));
        row.setStatus(SeminarProposalStatus.APPROVED);
        proposalRepository.save(row);
        // Áp dụng lại cả khi Giám đốc sửa quyết định có/không công.
        applySeminarDays(row, Boolean.TRUE.equals(row.getWithPay()));
        notificationService.notifySeminarProposalResult(row, true, "Giám đốc");
        return toMap(row);
    }

    /** Tự động hoàn thành các phiếu hội thảo đã hết thời gian (chạy theo lịch hàng ngày). */
    @Transactional
    public int completeDueProposals() {
        LocalDate today = LocalDate.now(VN);
        int n = 0;
        for (SeminarProposalRequest row : proposalRepository.findApprovedEndedBefore(today)) {
            try {
                completeProposal(row);
                n++;
            } catch (Exception e) {
                log.warn("Complete seminar proposal #{} failed: {}", row.getId(), e.getMessage());
            }
        }
        return n;
    }

    private void assertNoOverlappingSeminarProposal(
            Long employeeId, LocalDate from, LocalDate to, Long excludeId) {
        var overlapping = proposalRepository.findOverlappingForEmployee(employeeId, from, to, BLOCKING_OVERLAP);
        if (excludeId != null) {
            overlapping = overlapping.stream()
                    .filter(r -> !excludeId.equals(r.getId()))
                    .toList();
        }
        if (!overlapping.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Khoảng ngày trùng với phiếu hội thảo/công tác khác (đang chờ hoặc đã duyệt)");
        }
    }

    private void completeProposal(SeminarProposalRequest row) {
        row.setStatus(SeminarProposalStatus.COMPLETED);
        proposalRepository.save(row);
        notificationService.notifySeminarProposalCompleted(row);
    }

    @Transactional
    public Map<String, Object> cancel(Long id) {
        UserAccount actor = employeeService.currentUser();
        SeminarProposalRequest row = proposalRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất hội thảo"));
        boolean canCancel = actor.getRole() == UserRole.ADMIN
                || (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(actor.getId()));
        if (!canCancel) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền hủy phiếu này");
        }
        if (row.getStatus() == SeminarProposalStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phiếu đã thu hồi rồi");
        }
        if (row.getStatus() == SeminarProposalStatus.APPROVED
                || row.getStatus() == SeminarProposalStatus.COMPLETED) {
            revokeSeminarDays(row);
        }
        row.setWithPay(null);
        row.setSupportAmount(null);
        row.setStatus(SeminarProposalStatus.CANCELLED);
        proposalRepository.save(row);
        return toMap(row);
    }

    private void applySeminarDays(SeminarProposalRequest row, boolean withPay) {
        Employee emp = row.getEmployee();
        String supportAmount = row.getSupportAmount();
        for (LocalDate d = row.getStartDate(); !d.isAfter(row.getEndDate()); d = d.plusDays(1)) {
            applySeminarDay(emp, d, row.getAttendanceScope(), withPay,
                    supportAmount, row.getSeminarName(), row.getLocation());
        }
    }

    private void revokeSeminarDays(SeminarProposalRequest row) {
        for (LocalDate d = row.getStartDate(); !d.isAfter(row.getEndDate()); d = d.plusDays(1)) {
            AttendanceRecord rec = attendanceRecordRepository
                    .findByEmployeeAndWorkDate(row.getEmployee(), d)
                    .orElse(null);
            if (rec == null || !"SEMINAR".equals(rec.getStatus())) {
                continue;
            }
            rec.setStatus("ABSENT");
            rec.setLateMinutesExempt(false);
            rec.setNote(stripProtectedDayNotes(rec.getNote()));
            attendanceDayProcessor.applyToRecord(rec);
            attendanceRecordRepository.save(rec);
        }
    }

    private void applySeminarDay(
            Employee emp, LocalDate workDate, AttendanceShiftScope scope,
            boolean withPay, String supportAmount,
            String seminarName, String location) {
        AttendanceRecord rec = attendanceRecordRepository
                .findByEmployeeAndWorkDate(emp, workDate)
                .orElseGet(() -> AttendanceRecord.builder()
                        .employee(emp)
                        .workDate(workDate)
                        .status("ABSENT")
                        .build());
        rec.setLateMinutesExempt(scope == AttendanceShiftScope.FULL_DAY);
        String marker = "[SEMINAR:" + scope.name() + ":" + (withPay ? "PAID" : "UNPAID") + "]";
        String scopeLabel = switch (scope) {
            case MORNING -> "ca sáng";
            case AFTERNOON -> "ca chiều";
            case FULL_DAY -> "cả ngày";
        };
        String noteLine = (withPay ? "Hội thảo đã duyệt (có công, " : "Hội thảo đã duyệt (không công, ")
                + scopeLabel + ") " + marker;
        if (seminarName != null && !seminarName.isBlank()) {
            noteLine += ": " + seminarName.trim();
        }
        if (location != null && !location.isBlank()) {
            noteLine += " tại " + location.trim();
        }
        if (supportAmount != null && !supportAmount.isBlank()) {
            noteLine += " · Tiền hỗ trợ: " + supportAmount.trim();
        }
        rec.setNote(appendNote(stripProtectedDayNotes(rec.getNote()), noteLine));
        // Giữ nguyên log máy chấm để buổi không đi hội thảo vẫn được tính công bình thường.
        rec.setStatus("ABSENT");
        attendanceDayProcessor.applyToRecord(rec);
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
                    || p.startsWith("Nghỉ không lương đã duyệt")
                    || p.startsWith("Công tác đã duyệt")
                    || p.startsWith("Hội thảo đã duyệt")
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
        return existing + "; " + line;
    }

    private void notifyHrPending(SeminarProposalRequest row) {
        List<UserAccount> targets = userAccountRepository.findByRoleIn(
                List.of(UserRole.HR2, UserRole.HEAD_HR, UserRole.ADMIN));
        for (UserAccount u : targets) {
            if (u.isEnabled()) {
                notificationService.notifySeminarProposalPendingHr(u, row);
            }
        }
    }

    private void notifyDirectorsPending(SeminarProposalRequest row) {
        List<UserAccount> directors = userAccountRepository.findByDirectorApprovalEnabledTrueAndEnabledTrue();
        for (UserAccount u : directors) {
            if (u.isEnabled()) {
                notificationService.notifySeminarProposalPendingDirector(u, row);
            }
        }
    }

    private UserAccount ensureHeadOrAdmin() {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && !EmployeeService.isHeadRole(actor)
                && actor.getRole() != UserRole.HEAD_NURSING) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ Trưởng khoa/phòng hoặc Điều dưỡng trưởng được lập phiếu đề xuất hội thảo");
        }
        return actor;
    }

    private UserAccount ensureHrOrAdmin() {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN && !EmployeeService.isHr2Role(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ HCNS/ADMIN được duyệt bước này");
        }
        return actor;
    }

    private UserAccount ensureDirectorOrAdmin() {
        UserAccount actor = employeeService.currentUser();
        if (!com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Giám đốc/ADMIN được duyệt bước này");
        }
        return actor;
    }

    private UserAccount ensureCanView() {
        UserAccount actor = employeeService.currentUser();
        UserRole role = actor.getRole();
        if ((role == null || !role.isHr2()) && !com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(actor)
                && (role == null || !role.isHeadDepartment())
                && role != UserRole.HEAD_NURSING) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách phiếu hội thảo");
        }
        return actor;
    }

    private void ensureCanViewDetail(SeminarProposalRequest row) {
        UserAccount actor = employeeService.currentUser();
        UserRole role = actor.getRole();
        if ((role != null && role.isHr2()) || com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(actor)
                || (role != null && role.isHeadDepartment())
                || role == UserRole.HEAD_NURSING) {
            return;
        }
        if (role == UserRole.EMPLOYEE) {
            Long selfId = actorEmployeeId(actor);
            if (selfId != null && row.getEmployee().getId().equals(selfId)) {
                return;
            }
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem phiếu này");
    }

    private void ensureCanListForEmployee(Long employeeId) {
        UserAccount actor = employeeService.currentUser();
        UserRole role = actor.getRole();
        if ((role != null && role.isHr2()) || com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(actor)
                || (role != null && role.isHeadDepartment())
                || role == UserRole.HEAD_NURSING) {
            return;
        }
        if (role == UserRole.EMPLOYEE) {
            Long selfId = actorEmployeeId(actor);
            if (selfId != null && selfId.equals(employeeId)) {
                return;
            }
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách phiếu hội thảo");
    }

    private Employee requireSelfEmployee() {
        UserAccount actor = employeeService.currentUser();
        return employeeLinkService.findLinkedEmployee(actor)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản chưa liên kết nhân viên"));
    }

    private Long actorEmployeeId(UserAccount actor) {
        return employeeLinkService.findLinkedEmployee(actor).map(Employee::getId).orElse(null);
    }

    private Map<String, Object> toMap(SeminarProposalRequest r) {
        Employee e = r.getEmployee();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", e.getId());
        m.put("employeeCode", e.getEmployeeCode());
        m.put("employeeName", e.getFullName());
        m.put("dateOfBirth", e.getDateOfBirth() != null ? e.getDateOfBirth().toString() : null);
        m.put("positionTitle", e.getPosition() != null ? e.getPosition().getTitle() : null);
        m.put("departmentName", e.getDepartment() != null ? e.getDepartment().getName() : null);
        m.put("proposingDepartment", r.getProposingDepartment());
        m.put("seminarName", r.getSeminarName());
        m.put("location", r.getLocation());
        m.put("startDate", r.getStartDate() != null ? r.getStartDate().toString() : null);
        m.put("endDate", r.getEndDate() != null ? r.getEndDate().toString() : null);
        m.put("attendanceScope", r.getAttendanceScope() != null
                ? r.getAttendanceScope().name() : AttendanceShiftScope.FULL_DAY.name());
        m.put("plannedPeriod", formatPeriod(r.getStartDate(), r.getEndDate()));
        m.put("reason", r.getReason());
        m.put("employeeCommitmentAck", r.isEmployeeCommitmentAck());
        m.put("departmentCommitmentAck", r.isDepartmentCommitmentAck());
        m.put("status", r.getStatus().name());
        m.put("withPay", r.getWithPay());
        m.put("supportAmount", r.getSupportAmount());
        m.put("requestedByUsername", r.getRequestedBy() != null ? r.getRequestedBy().getUsername() : null);
        m.put("hrReviewerUsername", r.getHrReviewer() != null ? r.getHrReviewer().getUsername() : null);
        m.put("hrComment", r.getHrComment());
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : null);
        m.put("hrSignatureUrl", r.getHrSignaturePath() != null && !r.getHrSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/seminar/" + r.getId() + "/hr" : null);
        m.put("directorReviewerUsername",
                r.getDirectorReviewer() != null ? r.getDirectorReviewer().getUsername() : null);
        m.put("directorComment", r.getDirectorComment());
        m.put("directorReviewedAt",
                r.getDirectorReviewedAt() != null ? r.getDirectorReviewedAt().toString() : null);
        m.put("directorSignatureUrl",
                r.getDirectorSignaturePath() != null && !r.getDirectorSignaturePath().isBlank()
                        ? "/j1-api/v1/approval-signatures/seminar/" + r.getId() + "/director" : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }

    private static String formatPeriod(LocalDate from, LocalDate to) {
        if (from == null || to == null) return null;
        if (from.equals(to)) return from.format(VN_DATE);
        return from.format(VN_DATE) + " – " + to.format(VN_DATE);
    }

    private static String blankToNull(String s) {
        if (s == null || s.isBlank()) return null;
        return s.trim();
    }
}
