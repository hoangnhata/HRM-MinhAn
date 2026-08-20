package com.minhan.hrm.service;

import com.minhan.hrm.dto.probation.ProbationConversionCreateRequest;
import com.minhan.hrm.dto.probation.ProbationConversionReviewRequest;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.ProbationConversionRequestRepository;
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
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class ProbationConversionService {

    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final Set<ProbationConversionStatus> OPEN = Set.of(
            ProbationConversionStatus.PENDING_NURSING_HEAD,
            ProbationConversionStatus.PENDING_HR,
            ProbationConversionStatus.PENDING_DIRECTOR,
            ProbationConversionStatus.APPROVED);

    private final ProbationConversionRequestRepository conversionRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeLinkService employeeLinkService;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeService employeeService;
    private final NotificationService notificationService;
    private final ProbationFormTypeResolver formTypeResolver;
    private final ProbationEvaluationHelper evaluationHelper;
    private final ApprovalSignatureService approvalSignatureService;

    @Transactional(readOnly = true)
    public Map<String, Object> resolveFormType(Long employeeId) {
        Employee emp = employeeRepository.findById(employeeId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        ProbationFormType type = formTypeResolver.resolve(emp);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("employeeId", emp.getId());
        m.put("employeeName", emp.getFullName());
        m.put("positionTitle", emp.getPosition() != null ? emp.getPosition().getTitle() : null);
        m.put("formType", type.name());
        m.put("formTypeLabel", formTypeLabel(type));
        m.put("requiresScoring", true);
        m.put("maxScore", ProbationEvaluationHelper.maxScoreOf(type));
        m.put("criteria", ProbationEvaluationHelper.criteriaOf(type));
        return m;
    }

    @Transactional
    public Map<String, Object> create(ProbationConversionCreateRequest req) {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && !EmployeeService.isHeadRole(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ Trưởng khoa/phòng hoặc ADMIN được lập đơn chuyển chính thức");
        }
        Employee emp = employeeRepository.findById(req.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (emp.getStatus() != EmployeeStatus.PROBATION && emp.getStatus() != EmployeeStatus.INTERN) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ lập đơn cho nhân viên thử việc hoặc thực tập");
        }
        if (conversionRepository.existsByEmployeeAndStatusIn(emp, OPEN)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đang có đơn chuyển chính thức chờ duyệt hoặc chờ ngày hiệu lực");
        }
        if (req.getOfficialDate() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu ngày lên chính thức");
        }
        if (req.getReason() == null || req.getReason().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu lý do đề nghị");
        }

        ProbationFormType formType = resolveRequestedFormType(emp, req.getFormType());
        ensureCreatorAllowedForForm(actor, formType);

        ProbationEvaluationHelper.ScoreResult score =
                evaluationHelper.validateAndScore(formType, req.getScores());

        boolean nursingBlock = NursingBlockClassifier.matches(emp);
        ProbationConversionRequest row = ProbationConversionRequest.builder()
                .employee(emp)
                .officialDate(req.getOfficialDate())
                .reason(req.getReason().trim())
                .formType(formType)
                .mentorComment(blankToNull(req.getMentorComment()))
                .headDeptComment(blankToNull(req.getHeadDeptComment()))
                .wardNurseHeadComment(blankToNull(req.getWardNurseHeadComment()))
                .hospitalNurseHeadComment(blankToNull(req.getHospitalNurseHeadComment()))
                .scoresJson(score.scoresJson())
                .totalScore(score.totalScore())
                .maxScore(score.maxScore())
                .gradeLabel(score.gradeLabel())
                .status(nursingBlock
                        ? ProbationConversionStatus.PENDING_NURSING_HEAD
                        : ProbationConversionStatus.PENDING_HR)
                .requestedBy(actor)
                .build();
        row = conversionRepository.save(row);
        if (nursingBlock) {
            notifyNursingHeadPending(row);
        } else {
            notifyHrPending(row);
        }
        notificationService.notifyProbationConversionSubmittedToEmployee(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> update(Long id, ProbationConversionCreateRequest req) {
        UserAccount actor = employeeService.currentUser();
        ProbationConversionRequest row = conversionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn chuyển chính thức"));
        RequestEditSupport.ensureRequesterOrAdmin(actor, row.getRequestedBy(),
                "Không có quyền chỉnh sửa đơn này");
        RequestEditSupport.ensurePendingStatus(row.getStatus(), "đơn chuyển chính thức");

        Employee emp = row.getEmployee();
        if (!emp.getId().equals(req.getEmployeeId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đổi nhân viên khi chỉnh sửa đơn");
        }
        if (conversionRepository.findByEmployeeIdOrderByCreatedAtDesc(emp.getId()).stream()
                .anyMatch(r -> !r.getId().equals(id) && OPEN.contains(r.getStatus()))) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đang có đơn chuyển chính thức chờ duyệt hoặc chờ ngày hiệu lực");
        }
        if (req.getOfficialDate() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu ngày lên chính thức");
        }
        if (req.getReason() == null || req.getReason().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu lý do đề nghị");
        }

        ProbationFormType formType = resolveRequestedFormType(emp, req.getFormType());
        ensureCreatorAllowedForForm(actor, formType);
        ProbationEvaluationHelper.ScoreResult score =
                evaluationHelper.validateAndScore(formType, req.getScores());

        row.setOfficialDate(req.getOfficialDate());
        row.setReason(req.getReason().trim());
        row.setFormType(formType);
        row.setMentorComment(blankToNull(req.getMentorComment()));
        row.setHeadDeptComment(blankToNull(req.getHeadDeptComment()));
        row.setWardNurseHeadComment(blankToNull(req.getWardNurseHeadComment()));
        row.setHospitalNurseHeadComment(blankToNull(req.getHospitalNurseHeadComment()));
        row.setScoresJson(score.scoresJson());
        row.setTotalScore(score.totalScore());
        row.setMaxScore(score.maxScore());
        row.setGradeLabel(score.gradeLabel());
        row = conversionRepository.save(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingNursingHead() {
        UserAccount actor = ensureNursingHeadOrAdmin();
        return conversionRepository.findPendingWithDetails(ProbationConversionStatus.PENDING_NURSING_HEAD).stream()
                .filter(row -> actor.getRole() == UserRole.ADMIN
                        || NursingBlockClassifier.matches(row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingHr() {
        UserAccount actor = ensureCanViewAsHrOrAdminOrDirector();
        return conversionRepository.findPendingWithDetails(ProbationConversionStatus.PENDING_HR).stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingDirector() {
        UserAccount actor = ensureCanViewAsHrOrAdminOrDirector();
        return conversionRepository.findPendingWithDetails(ProbationConversionStatus.PENDING_DIRECTOR).stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listReviewHistory() {
        UserAccount actor = ensureCanViewHistory();
        return conversionRepository.findReviewHistoryWithDetails().stream()
                .filter(row -> {
                    if (actor.getRole() == UserRole.HEAD_NURSING) {
                        if (!employeeService.matchesNursingBlockScope(actor, row.getEmployee())) {
                            return false;
                        }
                        return row.getNursingHeadReviewedAt() != null
                                || row.getStatus() == ProbationConversionStatus.NURSING_HEAD_REJECTED;
                    }
                    return employeeService.matchesHrReviewScope(actor, row.getEmployee());
                })
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listMine() {
        UserAccount actor = employeeService.currentUser();
        return conversionRepository.findByRequestedBy_IdOrderByCreatedAtDesc(actor.getId()).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getById(Long id) {
        ProbationConversionRequest row = conversionRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn chuyển chính thức"));
        ensureCanViewRequest(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listByEmployee(Long employeeId) {
        ensureCanListForEmployee(employeeId);
        return conversionRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listRelatedToMe() {
        Employee self = requireSelfEmployee();
        return conversionRepository.findByEmployeeIdOrderByCreatedAtDesc(self.getId()).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional
    public Map<String, Object> nursingHeadReview(Long id, ProbationConversionReviewRequest body) {
        UserAccount nursingHead = ensureNursingHeadOrAdmin();
        ProbationConversionRequest row = conversionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn chuyển chính thức"));
        boolean hasReachedNursingHead = row.getStatus() == ProbationConversionStatus.PENDING_NURSING_HEAD
                || row.getNursingHeadReviewedAt() != null;
        if (!hasReachedNursingHead
                || row.getStatus() == ProbationConversionStatus.APPLIED
                || row.getStatus() == ProbationConversionStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn đã áp dụng hoặc đã hủy nên không thể đổi quyết định Trưởng phòng Điều dưỡng");
        }
        ProbationConversionStatus previousStatus = row.getStatus();
        if (nursingHead.getRole() == UserRole.HEAD_NURSING
                && !NursingBlockClassifier.matches(row.getEmployee())) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ duyệt đơn chuyển chính thức của khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa");
        }
        row.setNursingHeadReviewer(nursingHead);
        row.setNursingHeadReviewedAt(Instant.now());
        row.setNursingHeadComment(blankToNull(body.getComment()));
        row.setNursingHeadSignaturePath(
                approvalSignatureService.snapshotForApproval(nursingHead, "probation", row.getId(), "nursing-head"));

        boolean approved = Boolean.TRUE.equals(body.getApproved());
        if (!approved) {
            row.setStatus(ProbationConversionStatus.NURSING_HEAD_REJECTED);
            conversionRepository.save(row);
            notificationService.notifyProbationConversionResult(row, false, "Trưởng phòng Điều dưỡng");
            return toMap(row);
        }

        if (previousStatus == ProbationConversionStatus.PENDING_NURSING_HEAD
                || previousStatus == ProbationConversionStatus.NURSING_HEAD_REJECTED) {
            row.setStatus(ProbationConversionStatus.PENDING_HR);
        }
        conversionRepository.save(row);
        if (row.getStatus() == ProbationConversionStatus.PENDING_HR) {
            notifyHrPending(row);
        }
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, ProbationConversionReviewRequest body) {
        UserAccount hr = ensureHrOrAdmin();
        ProbationConversionRequest row = conversionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn chuyển chính thức"));
        boolean hasReachedHr = row.getStatus() == ProbationConversionStatus.PENDING_HR
                || row.getHrReviewedAt() != null;
        if (!hasReachedHr
                || row.getStatus() == ProbationConversionStatus.APPLIED
                || row.getStatus() == ProbationConversionStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn đã áp dụng hoặc đã hủy nên không thể đổi quyết định HCNS");
        }
        ProbationConversionStatus previousStatus = row.getStatus();
        row.setHrReviewer(hr);
        row.setHrReviewedAt(Instant.now());
        row.setHrComment(blankToNull(body.getComment()));
        row.setHrSignaturePath(approvalSignatureService.snapshotForApproval(hr, "probation", row.getId(), "hr"));

        // HCNS chỉ duyệt hoặc từ chối, không thực hiện phiếu đánh giá riêng.
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        if (!approved) {
            row.setStatus(ProbationConversionStatus.HR_REJECTED);
            conversionRepository.save(row);
            notificationService.notifyProbationConversionResult(row, false, "HCNS");
            return toMap(row);
        }

        row.setHrProposal(ProbationHrProposal.KY_HD);
        if (previousStatus == ProbationConversionStatus.PENDING_HR
                || previousStatus == ProbationConversionStatus.HR_REJECTED) {
            row.setStatus(ProbationConversionStatus.PENDING_DIRECTOR);
        }
        conversionRepository.save(row);
        if (row.getStatus() == ProbationConversionStatus.PENDING_DIRECTOR) {
            notifyDirectorsPending(row);
            notificationService.notifyProbationConversionForwardedToDirector(row);
        }
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> directorReview(Long id, ProbationConversionReviewRequest body) {
        UserAccount director = ensureDirectorOrAdmin();
        ProbationConversionRequest row = conversionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn chuyển chính thức"));
        boolean hasReachedDirector = row.getStatus() == ProbationConversionStatus.PENDING_DIRECTOR
                || row.getDirectorReviewedAt() != null;
        if (!hasReachedDirector
                || row.getStatus() == ProbationConversionStatus.APPLIED
                || row.getStatus() == ProbationConversionStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn đã áp dụng hoặc đã hủy nên không thể đổi quyết định Giám đốc");
        }
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setDirectorReviewer(director);
        row.setDirectorReviewedAt(Instant.now());
        row.setDirectorComment(blankToNull(body.getComment()));
        row.setDirectorSignaturePath(
                approvalSignatureService.snapshotForApproval(director, "probation", row.getId(), "director"));

        if (!approved) {
            row.setStatus(ProbationConversionStatus.DIRECTOR_REJECTED);
            conversionRepository.save(row);
            notificationService.notifyProbationConversionResult(row, false, "Giám đốc");
            return toMap(row);
        }

        LocalDate today = LocalDate.now(VN);
        if (!row.getOfficialDate().isAfter(today)) {
            applyConversion(row);
        } else {
            row.setStatus(ProbationConversionStatus.APPROVED);
            conversionRepository.save(row);
            notificationService.notifyProbationConversionResult(row, true, "Giám đốc");
        }
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> cancel(Long id) {
        UserAccount actor = employeeService.currentUser();
        ProbationConversionRequest row = conversionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn chuyển chính thức"));
        boolean canCancel = actor.getRole() == UserRole.ADMIN
                || (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(actor.getId()));
        if (!canCancel) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền hủy đơn này");
        }
        if (row.getStatus() == ProbationConversionStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn đã thu hồi rồi");
        }
        ProbationConversionStatus previous = row.getStatus();
        if (previous == ProbationConversionStatus.APPLIED) {
            revertOfficialIfThisConversion(row);
        }
        row.setStatus(ProbationConversionStatus.CANCELLED);
        conversionRepository.save(row);
        return toMap(row);
    }

    private void revertOfficialIfThisConversion(ProbationConversionRequest row) {
        Employee emp = row.getEmployee();
        boolean otherApplied = conversionRepository.findByEmployeeIdOrderByCreatedAtDesc(emp.getId()).stream()
                .anyMatch(r -> !r.getId().equals(row.getId())
                        && r.getStatus() == ProbationConversionStatus.APPLIED);
        if (otherApplied) {
            return;
        }
        employeeService.revertOfficialInternal(emp.getId());
    }

    @Transactional
    public int applyDueConversions() {
        LocalDate today = LocalDate.now(VN);
        List<ProbationConversionRequest> due = conversionRepository.findDueToApply(today);
        int n = 0;
        for (ProbationConversionRequest row : due) {
            try {
                applyConversion(row);
                n++;
            } catch (Exception e) {
                log.warn("Apply probation conversion #{} failed: {}", row.getId(), e.getMessage());
            }
        }
        return n;
    }

    private ProbationFormType resolveRequestedFormType(Employee emp, String requested) {
        ProbationFormType auto = formTypeResolver.resolve(emp);
        if (requested == null || requested.isBlank()) {
            return auto;
        }
        try {
            ProbationFormType override = ProbationFormType.valueOf(requested.trim().toUpperCase());
            // Không cho ép STAFF thành mẫu có chấm nếu hệ thống đã nhận là BS/ĐD — vẫn cho ADMIN override
            return override;
        } catch (IllegalArgumentException ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Loại mẫu đơn không hợp lệ");
        }
    }

    private void ensureCreatorAllowedForForm(UserAccount actor, ProbationFormType formType) {
        if (actor.getRole() == UserRole.ADMIN) {
            return;
        }
        if (formType == ProbationFormType.NURSE && !EmployeeService.isHeadRole(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Đơn điều dưỡng chỉ do Điều dưỡng trưởng (hoặc ADMIN) lập");
        }
        if (formType == ProbationFormType.DOCTOR && !EmployeeService.isHeadRole(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Đơn bác sĩ chỉ do Trưởng khoa (hoặc ADMIN) lập");
        }
        if (formType == ProbationFormType.STAFF && !EmployeeService.isHeadRole(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Đơn nhân viên thường chỉ do Trưởng khoa/phòng (hoặc ADMIN) lập");
        }
    }

    private void applyConversion(ProbationConversionRequest row) {
        if (row.getStatus() == ProbationConversionStatus.APPLIED) {
            return;
        }
        employeeService.applyOfficialInternal(row.getEmployee().getId(), row.getOfficialDate());
        row.setStatus(ProbationConversionStatus.APPLIED);
        row.setAppliedAt(Instant.now());
        conversionRepository.save(row);
        notificationService.notifyProbationConversionApplied(row);
    }

    private void notifyNursingHeadPending(ProbationConversionRequest row) {
        List<UserAccount> nursingHeads = userAccountRepository.findByRoleIn(
                List.of(UserRole.HEAD_NURSING, UserRole.ADMIN));
        for (UserAccount u : nursingHeads) {
            if (!employeeService.shouldReceiveNursingHeadPendingNotification(u, row.getEmployee())) {
                continue;
            }
            notificationService.notifyProbationConversionPendingNursingHead(u, row);
        }
    }

    private void notifyHrPending(ProbationConversionRequest row) {
        List<UserAccount> hrs = userAccountRepository.findByRoleIn(List.of(UserRole.HR2, UserRole.HEAD_HR, UserRole.ADMIN));
        for (UserAccount u : hrs) {
            if (!u.isEnabled()) {
                continue;
            }
            notificationService.notifyProbationConversionPendingHr(u, row);
        }
    }

    private void notifyDirectorsPending(ProbationConversionRequest row) {
        List<UserAccount> directors = userAccountRepository.findByDirectorApprovalEnabledTrueAndEnabledTrue();
        for (UserAccount u : directors) {
            if (!u.isEnabled()) {
                continue;
            }
            notificationService.notifyProbationConversionPendingDirector(u, row);
        }
    }

    private UserAccount ensureNursingHeadOrAdmin() {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() != UserRole.HEAD_NURSING && u.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Trưởng phòng Điều dưỡng/ADMIN được duyệt bước này");
        }
        return u;
    }

    private UserAccount ensureHrOrAdmin() {
        UserAccount u = employeeService.currentUser();
        if (!EmployeeService.isHr2Role(u) && u.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ HCNS/ADMIN được duyệt bước này");
        }
        return u;
    }

    private UserAccount ensureDirectorOrAdmin() {
        UserAccount u = employeeService.currentUser();
        if (!com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(u)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Giám đốc/ADMIN được duyệt bước này");
        }
        return u;
    }

    private UserAccount ensureCanViewAsHrOrAdminOrDirector() {
        UserAccount u = employeeService.currentUser();
        if (!EmployeeService.isHr2Role(u)
                && !EmployeeService.isHeadRole(u)
                && !com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(u)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách duyệt");
        }
        return u;
    }

    private UserAccount ensureCanViewHistory() {
        UserAccount u = employeeService.currentUser();
        if (EmployeeService.isHr2Role(u)
                || EmployeeService.isHeadRole(u)
                || u.getRole() == UserRole.HEAD_NURSING
                || com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(u)) {
            return u;
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem lịch sử duyệt");
    }

    private void ensureCanViewRequest(ProbationConversionRequest row) {
        UserAccount u = employeeService.currentUser();
        if (EmployeeService.isHr2Role(u)
                || com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(u)) {
            return;
        }
        if (u.getRole() == UserRole.HEAD_NURSING) {
            if (employeeService.matchesNursingBlockScope(u, row.getEmployee())) {
                return;
            }
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ xem đơn chuyển chính thức của khối Điều dưỡng");
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
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đơn này");
    }

    private void ensureCanListForEmployee(Long employeeId) {
        UserAccount actor = employeeService.currentUser();
        UserRole role = actor.getRole();
        if ((role != null && role.isHr2()) || com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(actor)
                || (role != null && role.isHeadDepartment())) {
            return;
        }
        if (role == UserRole.HEAD_NURSING) {
            Employee emp = employeeRepository.findById(employeeId).orElse(null);
            if (emp != null && employeeService.matchesNursingBlockScope(actor, emp)) {
                return;
            }
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ xem đơn chuyển chính thức của khối Điều dưỡng");
        }
        if (role == UserRole.EMPLOYEE) {
            Long selfId = actorEmployeeId(actor);
            if (selfId != null && selfId.equals(employeeId)) {
                return;
            }
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem");
    }

    private Employee requireSelfEmployee() {
        UserAccount actor = employeeService.currentUser();
        return employeeLinkService.findLinkedEmployee(actor)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản chưa liên kết nhân viên"));
    }

    private Long actorEmployeeId(UserAccount actor) {
        return employeeLinkService.findLinkedEmployee(actor).map(Employee::getId).orElse(null);
    }

    private static boolean blank(String s) {
        return s == null || s.isBlank();
    }

    private static String blankToNull(String s) {
        return s != null && !s.isBlank() ? s.trim() : null;
    }

    private static String formTypeLabel(ProbationFormType t) {
        return switch (t) {
            case DOCTOR -> "Bác sĩ";
            case NURSE -> "Điều dưỡng";
            case STAFF -> "Nhân viên";
        };
    }

    private Map<String, Object> toMap(ProbationConversionRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", r.getEmployee().getId());
        m.put("employeeCode", r.getEmployee().getEmployeeCode());
        m.put("employeeName", r.getEmployee().getFullName());
        m.put("employeeStatus", r.getEmployee().getStatus() != null ? r.getEmployee().getStatus().name() : null);
        m.put("positionTitle",
                r.getEmployee().getPosition() != null ? r.getEmployee().getPosition().getTitle() : null);
        m.put("departmentId", r.getEmployee().getDepartment() != null ? r.getEmployee().getDepartment().getId() : null);
        m.put("departmentName",
                r.getEmployee().getDepartment() != null ? r.getEmployee().getDepartment().getName() : null);
        m.put("officialDate", r.getOfficialDate().toString());
        m.put("reason", r.getReason());
        ProbationFormType formType = r.getFormType() != null ? r.getFormType() : ProbationFormType.STAFF;
        m.put("formType", formType.name());
        m.put("formTypeLabel", formTypeLabel(formType));
        m.put("requiresScoring", true);
        m.put("mentorComment", r.getMentorComment());
        m.put("headDeptComment", r.getHeadDeptComment());
        m.put("wardNurseHeadComment", r.getWardNurseHeadComment());
        m.put("hospitalNurseHeadComment", r.getHospitalNurseHeadComment());
        m.put("scoresJson", r.getScoresJson());
        m.put("totalScore", r.getTotalScore());
        m.put("maxScore", r.getMaxScore());
        m.put("gradeLabel", r.getGradeLabel());
        m.put("hrDocsComplete", r.getHrDocsComplete());
        m.put("hrDocsNote", r.getHrDocsNote());
        m.put("hrTrainingJoined", r.getHrTrainingJoined());
        m.put("hrRuleCompliance", r.getHrRuleCompliance());
        m.put("hrDeptFeedback", r.getHrDeptFeedback());
        m.put("hrProposal", r.getHrProposal() != null ? r.getHrProposal().name() : null);
        m.put("status", r.getStatus().name());
        m.put("requestedByUsername", r.getRequestedBy() != null ? r.getRequestedBy().getUsername() : null);
        m.put("nursingHeadReviewerUsername",
                r.getNursingHeadReviewer() != null ? r.getNursingHeadReviewer().getUsername() : null);
        m.put("nursingHeadComment", r.getNursingHeadComment());
        m.put("nursingHeadReviewedAt",
                r.getNursingHeadReviewedAt() != null ? r.getNursingHeadReviewedAt().toString() : null);
        m.put("nursingHeadSignatureUrl",
                r.getNursingHeadSignaturePath() != null && !r.getNursingHeadSignaturePath().isBlank()
                        ? "/j1-api/v1/approval-signatures/probation/" + r.getId() + "/nursing-head" : null);
        m.put("hrReviewerUsername", r.getHrReviewer() != null ? r.getHrReviewer().getUsername() : null);
        m.put("hrComment", r.getHrComment());
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : null);
        m.put("hrSignatureUrl", r.getHrSignaturePath() != null && !r.getHrSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/probation/" + r.getId() + "/hr" : null);
        m.put("directorReviewerUsername",
                r.getDirectorReviewer() != null ? r.getDirectorReviewer().getUsername() : null);
        m.put("directorComment", r.getDirectorComment());
        m.put("directorReviewedAt", r.getDirectorReviewedAt() != null ? r.getDirectorReviewedAt().toString() : null);
        m.put("directorSignatureUrl", r.getDirectorSignaturePath() != null && !r.getDirectorSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/probation/" + r.getId() + "/director" : null);
        m.put("appliedAt", r.getAppliedAt() != null ? r.getAppliedAt().toString() : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }
}
