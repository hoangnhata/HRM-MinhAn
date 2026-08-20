package com.minhan.hrm.service;

import com.minhan.hrm.dto.training.TrainingProposalCreateRequest;
import com.minhan.hrm.dto.training.TrainingProposalReviewRequest;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.TrainingProposalRequestRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.util.PlannedPeriodParser;
import com.minhan.hrm.service.support.RequestEditSupport;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class TrainingProposalService {

    private static final Set<TrainingProposalStatus> OPEN = Set.of(
            TrainingProposalStatus.PENDING_HR,
            TrainingProposalStatus.PENDING_DIRECTOR);
    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");

    private final TrainingProposalRequestRepository proposalRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeLinkService employeeLinkService;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeService employeeService;
    private final NotificationService notificationService;
    private final ApprovalSignatureService approvalSignatureService;

    @Transactional
    public Map<String, Object> create(TrainingProposalCreateRequest req) {
        UserAccount actor = ensureHeadOrAdmin();
        Employee emp = employeeRepository.findById(req.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (emp.getStatus() == EmployeeStatus.TERMINATED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đề xuất đào tạo cho nhân viên đã nghỉ việc");
        }
        if (proposalRepository.existsByEmployeeAndStatusIn(emp, OPEN)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đang có phiếu đề xuất đào tạo chờ duyệt");
        }
        if (!Boolean.TRUE.equals(req.getEmployeeCommitmentAck())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần xác nhận cam kết của nhân viên được cử đi đào tạo");
        }
        if (!Boolean.TRUE.equals(req.getDepartmentCommitmentAck())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần xác nhận cam kết của Khoa/Phòng đề xuất");
        }

        String plannedPeriod = req.getPlannedPeriod().trim();
        var period = PlannedPeriodParser.parse(plannedPeriod);

        TrainingProposalRequest row = TrainingProposalRequest.builder()
                .employee(emp)
                .proposingDepartment(req.getProposingDepartment().trim())
                .courseName(req.getCourseName().trim())
                .location(req.getLocation().trim())
                .plannedPeriod(plannedPeriod)
                .startDate(period.map(PlannedPeriodParser.Period::start).orElse(null))
                .endDate(period.map(PlannedPeriodParser.Period::end).orElse(null))
                .tuitionFee(blankToNull(req.getTuitionFee()))
                .trainingGoal(req.getTrainingGoal().trim())
                .reason(req.getReason().trim())
                .employeeCommitmentAck(true)
                .departmentCommitmentAck(true)
                .status(TrainingProposalStatus.PENDING_HR)
                .requestedBy(actor)
                .build();
        row = proposalRepository.save(row);

        notifyHrPending(row);
        notificationService.notifyTrainingProposalSubmittedToEmployee(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> update(Long id, TrainingProposalCreateRequest req) {
        UserAccount actor = employeeService.currentUser();
        TrainingProposalRequest row = proposalRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất đào tạo"));
        RequestEditSupport.ensureRequesterOrAdmin(actor, row.getRequestedBy(),
                "Không có quyền chỉnh sửa phiếu này");
        RequestEditSupport.ensurePendingStatus(row.getStatus(), "phiếu đào tạo");

        Employee emp = row.getEmployee();
        if (!emp.getId().equals(req.getEmployeeId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đổi nhân viên khi chỉnh sửa phiếu");
        }
        if (proposalRepository.findByEmployeeIdOrderByCreatedAtDesc(emp.getId()).stream()
                .anyMatch(p -> !p.getId().equals(id) && OPEN.contains(p.getStatus()))) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đang có phiếu đề xuất đào tạo chờ duyệt khác");
        }
        if (!Boolean.TRUE.equals(req.getEmployeeCommitmentAck())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần xác nhận cam kết của nhân viên được cử đi đào tạo");
        }
        if (!Boolean.TRUE.equals(req.getDepartmentCommitmentAck())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần xác nhận cam kết của Khoa/Phòng đề xuất");
        }

        String plannedPeriod = req.getPlannedPeriod().trim();
        var period = PlannedPeriodParser.parse(plannedPeriod);

        row.setProposingDepartment(req.getProposingDepartment().trim());
        row.setCourseName(req.getCourseName().trim());
        row.setLocation(req.getLocation().trim());
        row.setPlannedPeriod(plannedPeriod);
        row.setStartDate(period.map(PlannedPeriodParser.Period::start).orElse(null));
        row.setEndDate(period.map(PlannedPeriodParser.Period::end).orElse(null));
        row.setTuitionFee(blankToNull(req.getTuitionFee()));
        row.setTrainingGoal(req.getTrainingGoal().trim());
        row.setReason(req.getReason().trim());
        row.setEmployeeCommitmentAck(true);
        row.setDepartmentCommitmentAck(true);
        row = proposalRepository.save(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingHr() {
        UserAccount actor = ensureCanView();
        return proposalRepository.findPendingWithDetails(TrainingProposalStatus.PENDING_HR).stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingDirector() {
        UserAccount actor = ensureCanView();
        return proposalRepository.findPendingWithDetails(TrainingProposalStatus.PENDING_DIRECTOR).stream()
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
        TrainingProposalRequest row = proposalRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất đào tạo"));
        ensureCanViewDetail(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, TrainingProposalReviewRequest body) {
        UserAccount hr = ensureHrOrAdmin();
        TrainingProposalRequest row = proposalRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất đào tạo"));
        boolean hasReachedHr = row.getStatus() == TrainingProposalStatus.PENDING_HR
                || row.getHrReviewedAt() != null;
        if (!hasReachedHr
                || row.getStatus() == TrainingProposalStatus.COMPLETED
                || row.getStatus() == TrainingProposalStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Phiếu đã hoàn thành hoặc đã hủy nên không thể đổi quyết định HCNS");
        }
        TrainingProposalStatus previousStatus = row.getStatus();
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setHrReviewer(hr);
        row.setHrReviewedAt(Instant.now());
        row.setHrComment(blankToNull(body.getComment()));
        row.setHrSignaturePath(approvalSignatureService.snapshotForApproval(hr, "training", row.getId(), "hr"));

        if (!approved) {
            row.setStatus(TrainingProposalStatus.HR_REJECTED);
            proposalRepository.save(row);
            refreshEmployeeTrainingFlag(row.getEmployee());
            notificationService.notifyTrainingProposalResult(row, false, "HCNS");
            return toMap(row);
        }

        String monthlySupport = blankToNull(body.getMonthlySupport());
        String postCourseCommitment = blankToNull(body.getPostCourseCommitment());
        if (monthlySupport == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập tiền hỗ trợ hàng tháng trước khi duyệt");
        }
        if (postCourseCommitment == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Cần nhập thời gian cam kết sau khóa học trước khi duyệt");
        }
        row.setMonthlySupport(monthlySupport);
        row.setPostCourseCommitment(postCourseCommitment);

        if (previousStatus == TrainingProposalStatus.PENDING_HR
                || previousStatus == TrainingProposalStatus.HR_REJECTED) {
            row.setStatus(TrainingProposalStatus.PENDING_DIRECTOR);
        }
        proposalRepository.save(row);
        if (row.getStatus() == TrainingProposalStatus.PENDING_DIRECTOR) {
            notifyDirectorsPending(row);
            notificationService.notifyTrainingProposalForwardedToDirector(row);
        }
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> directorReview(Long id, TrainingProposalReviewRequest body) {
        UserAccount director = ensureDirectorOrAdmin();
        TrainingProposalRequest row = proposalRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất đào tạo"));
        boolean hasReachedDirector = row.getStatus() == TrainingProposalStatus.PENDING_DIRECTOR
                || row.getDirectorReviewedAt() != null;
        if (!hasReachedDirector
                || row.getStatus() == TrainingProposalStatus.COMPLETED
                || row.getStatus() == TrainingProposalStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Phiếu đã hoàn thành hoặc đã hủy nên không thể đổi quyết định Giám đốc");
        }
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setDirectorReviewer(director);
        row.setDirectorReviewedAt(Instant.now());
        row.setDirectorComment(blankToNull(body.getComment()));
        row.setDirectorSignaturePath(
                approvalSignatureService.snapshotForApproval(director, "training", row.getId(), "director"));

        if (!approved) {
            row.setStatus(TrainingProposalStatus.DIRECTOR_REJECTED);
            proposalRepository.save(row);
            refreshEmployeeTrainingFlag(row.getEmployee());
            notificationService.notifyTrainingProposalResult(row, false, "Giám đốc");
            return toMap(row);
        }

        row.setStatus(TrainingProposalStatus.APPROVED);
        proposalRepository.save(row);

        Employee emp = row.getEmployee();
        emp.setOnTraining(true);
        employeeRepository.save(emp);

        notificationService.notifyTrainingProposalResult(row, true, "Giám đốc");
        return toMap(row);
    }

    private void refreshEmployeeTrainingFlag(Employee employee) {
        boolean stillTraining = proposalRepository.existsByEmployeeAndStatusIn(
                employee, Set.of(TrainingProposalStatus.APPROVED));
        employee.setOnTraining(stillTraining);
        employeeRepository.save(employee);
    }

    @Transactional
    public Map<String, Object> markCompleted(Long id) {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN && !EmployeeService.isHr2Role(actor)
                && !EmployeeService.isHeadRole(actor)
                && actor.getRole() != UserRole.HEAD_NURSING) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền đánh dấu hoàn thành đào tạo");
        }
        TrainingProposalRequest row = proposalRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất đào tạo"));
        if (row.getStatus() != TrainingProposalStatus.APPROVED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ đánh dấu hoàn thành với phiếu đã được duyệt");
        }
        completeProposal(row);
        return toMap(row);
    }

    /** Tự động hoàn thành các phiếu đào tạo đã hết thời gian (chạy theo lịch hàng ngày). */
    @Transactional
    public int completeDueProposals() {
        LocalDate today = LocalDate.now(VN);
        int n = 0;
        for (TrainingProposalRequest row : proposalRepository.findApprovedWithEmployee()) {
            try {
                LocalDate end = resolveEndDate(row);
                if (end != null && end.isBefore(today)) {
                    completeProposal(row);
                    n++;
                }
            } catch (Exception e) {
                log.warn("Complete training proposal #{} failed: {}", row.getId(), e.getMessage());
            }
        }
        return n;
    }

    private void completeProposal(TrainingProposalRequest row) {
        row.setStatus(TrainingProposalStatus.COMPLETED);
        proposalRepository.save(row);

        Employee emp = row.getEmployee();
        boolean stillTraining = proposalRepository.existsByEmployeeAndStatusIn(
                emp, Set.of(TrainingProposalStatus.APPROVED));
        if (!stillTraining) {
            emp.setOnTraining(false);
            employeeRepository.save(emp);
        }
        notificationService.notifyTrainingProposalCompleted(row);
    }

    private LocalDate resolveEndDate(TrainingProposalRequest row) {
        if (row.getEndDate() != null) {
            return row.getEndDate();
        }
        if (row.getPlannedPeriod() != null && !row.getPlannedPeriod().isBlank()) {
            return PlannedPeriodParser.parseEnd(row.getPlannedPeriod()).orElse(null);
        }
        return null;
    }

    @Transactional
    public Map<String, Object> cancel(Long id) {
        UserAccount actor = employeeService.currentUser();
        TrainingProposalRequest row = proposalRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đề xuất đào tạo"));
        boolean canCancel = actor.getRole() == UserRole.ADMIN
                || (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(actor.getId()));
        if (!canCancel) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền hủy phiếu này");
        }
        if (row.getStatus() == TrainingProposalStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phiếu đã thu hồi rồi");
        }
        TrainingProposalStatus previous = row.getStatus();
        row.setStatus(TrainingProposalStatus.CANCELLED);
        proposalRepository.save(row);
        if (previous == TrainingProposalStatus.APPROVED || previous == TrainingProposalStatus.COMPLETED) {
            refreshEmployeeTrainingFlag(row.getEmployee());
        }
        return toMap(row);
    }

    private void notifyHrPending(TrainingProposalRequest row) {
        List<UserAccount> targets = userAccountRepository.findByRoleIn(
                List.of(UserRole.HR2, UserRole.HEAD_HR, UserRole.ADMIN));
        for (UserAccount u : targets) {
            if (u.isEnabled()) {
                notificationService.notifyTrainingProposalPendingHr(u, row);
            }
        }
    }

    private void notifyDirectorsPending(TrainingProposalRequest row) {
        List<UserAccount> directors = userAccountRepository.findByDirectorApprovalEnabledTrueAndEnabledTrue();
        for (UserAccount u : directors) {
            if (u.isEnabled()) {
                notificationService.notifyTrainingProposalPendingDirector(u, row);
            }
        }
    }

    private UserAccount ensureHeadOrAdmin() {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && !EmployeeService.isHeadRole(actor)
                && actor.getRole() != UserRole.HEAD_NURSING) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ Trưởng khoa/phòng hoặc Điều dưỡng trưởng được lập phiếu đề xuất đào tạo");
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
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách phiếu đào tạo");
        }
        return actor;
    }

    private void ensureCanViewDetail(TrainingProposalRequest row) {
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
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách phiếu đào tạo");
    }

    private Employee requireSelfEmployee() {
        UserAccount actor = employeeService.currentUser();
        return employeeLinkService.findLinkedEmployee(actor)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản chưa liên kết nhân viên"));
    }

    private Long actorEmployeeId(UserAccount actor) {
        return employeeLinkService.findLinkedEmployee(actor).map(Employee::getId).orElse(null);
    }

    private Map<String, Object> toMap(TrainingProposalRequest r) {
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
        m.put("courseName", r.getCourseName());
        m.put("location", r.getLocation());
        m.put("plannedPeriod", r.getPlannedPeriod());
        m.put("startDate", r.getStartDate() != null ? r.getStartDate().toString() : null);
        m.put("endDate", r.getEndDate() != null ? r.getEndDate().toString() : null);
        m.put("tuitionFee", r.getTuitionFee());
        m.put("monthlySupport", r.getMonthlySupport());
        m.put("postCourseCommitment", r.getPostCourseCommitment());
        m.put("trainingGoal", r.getTrainingGoal());
        m.put("reason", r.getReason());
        m.put("employeeCommitmentAck", r.isEmployeeCommitmentAck());
        m.put("departmentCommitmentAck", r.isDepartmentCommitmentAck());
        m.put("status", r.getStatus().name());
        m.put("requestedByUsername", r.getRequestedBy() != null ? r.getRequestedBy().getUsername() : null);
        m.put("hrReviewerUsername", r.getHrReviewer() != null ? r.getHrReviewer().getUsername() : null);
        m.put("hrComment", r.getHrComment());
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : null);
        m.put("hrSignatureUrl", r.getHrSignaturePath() != null && !r.getHrSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/training/" + r.getId() + "/hr" : null);
        m.put("directorReviewerUsername",
                r.getDirectorReviewer() != null ? r.getDirectorReviewer().getUsername() : null);
        m.put("directorComment", r.getDirectorComment());
        m.put("directorReviewedAt",
                r.getDirectorReviewedAt() != null ? r.getDirectorReviewedAt().toString() : null);
        m.put("directorSignatureUrl",
                r.getDirectorSignaturePath() != null && !r.getDirectorSignaturePath().isBlank()
                        ? "/j1-api/v1/approval-signatures/training/" + r.getId() + "/director" : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }

    private static String blankToNull(String s) {
        if (s == null || s.isBlank()) return null;
        return s.trim();
    }
}
