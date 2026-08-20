package com.minhan.hrm.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.dto.evaluation.NursingEvaluationReviewRequest;
import com.minhan.hrm.dto.evaluation.NursingEvaluationSubmitRequest;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.NursingEvaluationRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.security.ApprovalAuthority;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.*;

@Service
@RequiredArgsConstructor
public class NursingEvaluationService {

    public static final String TEMPLATE_MA2026 = "DD_KTV_HS_MA_2026";

    private final NursingEvaluationTemplateService templateService;
    private final NursingEvaluationRepository nursingEvaluationRepository;
    private final EmployeeService employeeService;
    private final UserAccountRepository userAccountRepository;
    private final ApprovalSignatureService approvalSignatureService;
    private final NotificationService notificationService;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public Map<String, Object> getTemplateForUi(String code) {
        JsonNode root = templateService.getTemplate(code);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("code", text(root, "code"));
        m.put("name", text(root, "name"));
        m.put("version", root.has("version") ? root.get("version").asInt() : 1);
        m.put("baseMaxPoints", root.has("baseMaxPoints") ? root.get("baseMaxPoints").asInt() : 90);
        m.put("criteriaGroups", objectMapper.convertValue(root.get("criteriaGroups"),
                new TypeReference<List<Map<String, Object>>>() {
                }));
        m.put("note", text(root, "note"));
        m.put("gradingScale", List.of(
                Map.of("min", 90, "label", "Xuất sắc", "proposal", "Xét tăng lương sớm"),
                Map.of("min", 80, "label", "Tốt", "proposal", "Ưu tiên, theo dõi"),
                Map.of("min", 65, "label", "Khá", "proposal", "Chưa xét"),
                Map.of("min", 0, "label", "Chưa đạt", "proposal", "Đào tạo lại")
        ));
        return m;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listForEmployee(Long employeeId) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanView(emp);
        UserAccount current = employeeService.currentUser();
        boolean selfOnly = isSelfViewerOnly(current, emp);
        return nursingEvaluationRepository.findByEmployeeOrderByPeriodYearDescPeriodMonthDesc(emp).stream()
                .filter(n -> !selfOnly || n.getStatus() == NursingEvaluationStatus.APPROVED)
                .map(this::toMap)
                .toList();
    }

    /** Phiếu đánh giá đã duyệt của chính nhân viên đang đăng nhập. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> listMineApproved() {
        UserAccount current = employeeService.currentUser();
        Employee self = employeeService.linkedEmployee(current)
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST,
                        "Tài khoản chưa liên kết hồ sơ nhân viên"));
        return nursingEvaluationRepository.findByEmployeeOrderByPeriodYearDescPeriodMonthDesc(self).stream()
                .filter(n -> n.getStatus() == NursingEvaluationStatus.APPROVED)
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HR','HR2','HEAD_DEPARTMENT','HEAD_NURSING','DIRECTOR')")
    public List<Map<String, Object>> listPeriodEvaluationStatus(int year, int month, String templateCode) {
        UserAccount current = employeeService.currentUser();
        List<Map<String, Object>> out = new ArrayList<>();
        for (NursingEvaluation n : nursingEvaluationRepository.listMonthlyForTemplate(year, month, templateCode)) {
            Employee emp = n.getEmployee();
            if (!NursingBlockClassifier.matches(emp) || !canViewQuiet(current, emp)) {
                continue;
            }
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("employeeId", emp.getId());
            m.put("evaluationId", n.getId());
            m.put("status", n.getStatus() != null ? n.getStatus().name() : null);
            m.put("totalScore", n.getTotalScore());
            m.put("overallGrade", n.getOverallGrade());
            out.add(m);
        }
        return out;
    }

    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HR','HR2','HEAD_NURSING','DIRECTOR')")
    public List<Map<String, Object>> listMonthlySummary(int year, int month, String templateCode) {
        UserAccount current = employeeService.currentUser();
        List<Map<String, Object>> out = new ArrayList<>();
        for (NursingEvaluation n : nursingEvaluationRepository.listMonthlyForTemplate(year, month, templateCode)) {
            if (!NursingBlockClassifier.matches(n.getEmployee()) || !canViewQuiet(current, n.getEmployee())) {
                continue;
            }
            if (n.getStatus() == NursingEvaluationStatus.CANCELLED
                    || n.getStatus() == NursingEvaluationStatus.DRAFT) {
                continue;
            }
            out.add(toSummaryRow(n));
        }
        return out;
    }

    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HR2','HEAD_NURSING','DIRECTOR')")
    public List<Map<String, Object>> listPending() {
        UserAccount current = employeeService.currentUser();
        Set<NursingEvaluationStatus> initial = switch (current.getRole()) {
            case ADMIN -> Set.of(
                    NursingEvaluationStatus.PENDING_NURSING_HEAD,
                    NursingEvaluationStatus.PENDING_HR,
                    NursingEvaluationStatus.PENDING_DIRECTOR);
            case HEAD_NURSING -> Set.of(NursingEvaluationStatus.PENDING_NURSING_HEAD);
            case HR2 -> Set.of(NursingEvaluationStatus.PENDING_HR);
            case DIRECTOR -> Set.of(NursingEvaluationStatus.PENDING_DIRECTOR);
            default -> Set.of();
        };
        final Set<NursingEvaluationStatus> statuses =
                initial.isEmpty() && ApprovalAuthority.isDirectorApprover(current)
                        ? Set.of(NursingEvaluationStatus.PENDING_DIRECTOR)
                        : initial;
        if (statuses.isEmpty()) {
            return List.of();
        }
        return nursingEvaluationRepository.findPendingWithDetails(statuses).stream()
                .filter(n -> NursingBlockClassifier.matches(n.getEmployee()))
                .filter(n -> canViewQuiet(current, n.getEmployee()))
                .filter(n -> statuses.contains(n.getStatus()))
                .map(this::toMap)
                .toList();
    }

    /** Lịch sử phiếu đã duyệt / từ chối ở bước của người xem. */
    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HR2','HEAD_NURSING','DIRECTOR')")
    public List<Map<String, Object>> listHistory() {
        UserAccount current = employeeService.currentUser();
        return nursingEvaluationRepository.findHistoryWithDetails(
                        Set.of(NursingEvaluationStatus.DRAFT, NursingEvaluationStatus.CANCELLED),
                        Set.of(
                                NursingEvaluationStatus.APPROVED,
                                NursingEvaluationStatus.NURSING_HEAD_REJECTED,
                                NursingEvaluationStatus.HR_REJECTED,
                                NursingEvaluationStatus.DIRECTOR_REJECTED))
                .stream()
                .filter(n -> NursingBlockClassifier.matches(n.getEmployee()))
                .filter(n -> canViewQuiet(current, n.getEmployee()))
                .filter(n -> {
                    if (current.getRole() == UserRole.ADMIN) {
                        return n.getHeadReviewedAt() != null
                                || n.getHrReviewedAt() != null
                                || n.getDirectorReviewedAt() != null
                                || n.getStatus() == NursingEvaluationStatus.APPROVED
                                || n.getStatus() == NursingEvaluationStatus.NURSING_HEAD_REJECTED
                                || n.getStatus() == NursingEvaluationStatus.HR_REJECTED
                                || n.getStatus() == NursingEvaluationStatus.DIRECTOR_REJECTED;
                    }
                    if (current.getRole() == UserRole.HEAD_NURSING) {
                        return n.getHeadReviewedAt() != null;
                    }
                    if (EmployeeService.isHr2Role(current)) {
                        return n.getHrReviewedAt() != null;
                    }
                    if (ApprovalAuthority.isDirectorApprover(current)) {
                        return n.getDirectorReviewedAt() != null
                                || n.getStatus() == NursingEvaluationStatus.APPROVED
                                || n.getStatus() == NursingEvaluationStatus.DIRECTOR_REJECTED;
                    }
                    return false;
                })
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getRecordDetail(Long evaluationId) {
        NursingEvaluation n = nursingEvaluationRepository.findDetailById(evaluationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá"));
        UserAccount current = employeeService.currentUser();
        assertCanView(n.getEmployee());
        if (isSelfViewerOnly(current, n.getEmployee())
                && n.getStatus() != NursingEvaluationStatus.APPROVED) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ xem được phiếu đánh giá sau khi Giám đốc duyệt xong");
        }
        return toMap(n);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HEAD_DEPARTMENT')")
    @Transactional
    public Map<String, Object> submit(NursingEvaluationSubmitRequest req) {
        UserAccount actor = employeeService.currentUser();
        Employee emp = employeeService.requireEmployeeEntity(req.getEmployeeId());
        assertCanCreate(actor, emp);
        if (EmployeeService.isHeadRole(actor)) {
            employeeService.assertCanAccessEmployee(emp);
        }

        JsonNode template = templateService.getTemplate(req.getTemplateCode());
        JsonNode groups = template.get("criteriaGroups");
        if (groups == null || !groups.isArray()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mẫu đánh giá không hợp lệ");
        }

        Map<String, Set<BigDecimal>> allowed = buildAllowedPoints(groups);
        Map<String, Object> scores = new LinkedHashMap<>();
        for (JsonNode g : groups) {
            if (isCouncilCriterion(g)) {
                continue;
            }
            String cid = g.get("id").asText();
            boolean optionalExtra = isBonusCriterion(g) || isPenaltyCriterion(g);
            BigDecimal val = req.getScores() != null ? req.getScores().get(cid) : null;
            if (val == null) {
                if (optionalExtra) {
                    val = BigDecimal.ZERO;
                } else {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu điểm cho tiêu chí: " + cid);
                }
            }
            val = val.setScale(2, RoundingMode.HALF_UP);
            Set<BigDecimal> allowedPts = allowed.get(cid);
            if (allowedPts == null || !containsPoint(allowedPts, val)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Điểm không hợp lệ cho " + cid + ": " + val);
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("points", val);
            if (req.getNotes() != null && req.getNotes().get(cid) != null
                    && !req.getNotes().get(cid).isBlank()) {
                row.put("note", req.getNotes().get(cid).trim());
            }
            scores.put(cid, row);
        }

        ScoreAgg agg = computeScore(groups, scores, template);
        Optional<NursingEvaluation> existing = nursingEvaluationRepository
                .findByEmployeeAndPeriodYearAndPeriodMonthAndTemplateCode(
                        emp, req.getPeriodYear(), req.getPeriodMonth(), req.getTemplateCode());

        NursingEvaluation row = existing.orElseGet(NursingEvaluation::new);
        if (existing.isPresent()) {
            NursingEvaluationStatus st = row.getStatus();
            if (st == NursingEvaluationStatus.APPROVED
                    || st == NursingEvaluationStatus.PENDING_DIRECTOR
                    || st == NursingEvaluationStatus.PENDING_HR
                    || st == NursingEvaluationStatus.PENDING_NURSING_HEAD) {
                boolean creator = row.getEvaluator() != null
                        && row.getEvaluator().getId().equals(actor.getId());
                if (!(actor.getRole() == UserRole.ADMIN
                        || (creator && (st == NursingEvaluationStatus.PENDING_NURSING_HEAD
                        || st == NursingEvaluationStatus.DRAFT
                        || st == NursingEvaluationStatus.NURSING_HEAD_REJECTED)))) {
                    throw new ApiException(HttpStatus.BAD_REQUEST,
                            "Phiếu đang chờ duyệt hoặc đã duyệt — thu hồi trước khi sửa");
                }
            }
            if (st == NursingEvaluationStatus.CANCELLED
                    || st == NursingEvaluationStatus.NURSING_HEAD_REJECTED) {
                row.setEvaluatorSignaturePath(null);
                row.setEvaluatorSignedAt(null);
                row.setHeadReviewer(null);
                row.setHeadReviewedAt(null);
                row.setHeadComment(null);
                row.setHeadSignaturePath(null);
                row.setHrReviewer(null);
                row.setHrReviewedAt(null);
                row.setHrComment(null);
                row.setHrSignaturePath(null);
                row.setDirectorReviewer(null);
                row.setDirectorReviewedAt(null);
                row.setDirectorComment(null);
                row.setDirectorSignaturePath(null);
            }
        }

        row.setEmployee(emp);
        row.setEvaluator(actor);
        row.setPeriodYear(req.getPeriodYear());
        row.setPeriodMonth(req.getPeriodMonth());
        row.setTemplateCode(req.getTemplateCode());
        try {
            row.setScoresJson(objectMapper.writeValueAsString(scores));
        } catch (Exception e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không lưu được điểm");
        }
        row.setComments(blankToNull(req.getComments()));
        row.setTotalScore(agg.total());
        row.setOverallGrade(agg.grade());
        row.setTotalTruongKhoa(agg.total());
        row.setGradeTruongKhoa(agg.grade());
        row.setTotalDdt(null);
        row.setGradeDdt(null);
        row.setTotalSelf(null);
        row.setGradeSelf(null);

        boolean submit = Boolean.TRUE.equals(req.getSubmitForReview());
        if (submit) {
            // Trưởng khoa / ĐDT lập + ký → gửi Trưởng phòng Điều dưỡng
            row.setStatus(NursingEvaluationStatus.PENDING_NURSING_HEAD);
            row = nursingEvaluationRepository.save(row);
            row.setEvaluatorSignaturePath(
                    approvalSignatureService.snapshotForApproval(actor, "nursing-eval", row.getId(), "evaluator"));
            row.setEvaluatorSignedAt(Instant.now());
            row = nursingEvaluationRepository.save(row);
            notifyNursingHeadsPending(row);
        } else {
            row.setStatus(NursingEvaluationStatus.DRAFT);
            row.setEvaluatorSignaturePath(null);
            row.setEvaluatorSignedAt(null);
            row = nursingEvaluationRepository.save(row);
        }
        return toMap(row);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Transactional
    public Map<String, Object> nursingHeadReview(Long id, NursingEvaluationReviewRequest body) {
        UserAccount reviewer = employeeService.currentUser();
        NursingEvaluation row = nursingEvaluationRepository.findDetailById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá"));
        if (reviewer.getRole() == UserRole.HEAD_NURSING
                && !NursingBlockClassifier.matches(row.getEmployee())) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ duyệt phiếu đánh giá trong khối Điều dưỡng");
        }
        boolean reached = row.getStatus() == NursingEvaluationStatus.PENDING_NURSING_HEAD
                || row.getHeadReviewedAt() != null;
        if (!reached || row.getStatus() == NursingEvaluationStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Phiếu không thể duyệt ở bước Trưởng phòng Điều dưỡng");
        }
        NursingEvaluationStatus previous = row.getStatus();
        row.setHeadReviewer(reviewer);
        row.setHeadReviewedAt(Instant.now());
        row.setHeadComment(blankToNull(body.getComment()));
        row.setHeadSignaturePath(
                approvalSignatureService.snapshotForApproval(
                        reviewer, "nursing-eval", row.getId(), "nursing-head"));
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        if (!approved) {
            row.setStatus(NursingEvaluationStatus.NURSING_HEAD_REJECTED);
            nursingEvaluationRepository.save(row);
            notificationService.notifyNursingEvaluationResult(row, false, "Trưởng phòng Điều dưỡng");
            return toMap(row);
        }
        if (previous == NursingEvaluationStatus.PENDING_NURSING_HEAD
                || previous == NursingEvaluationStatus.NURSING_HEAD_REJECTED) {
            row.setStatus(NursingEvaluationStatus.PENDING_HR);
        }
        nursingEvaluationRepository.save(row);
        if (row.getStatus() == NursingEvaluationStatus.PENDING_HR) {
            notifyHrPending(row);
        }
        return toMap(row);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR2')")
    @Transactional
    public Map<String, Object> hrReview(Long id, NursingEvaluationReviewRequest body) {
        UserAccount reviewer = ensureHrOrAdmin();
        NursingEvaluation row = nursingEvaluationRepository.findDetailById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá"));
        boolean reached = row.getStatus() == NursingEvaluationStatus.PENDING_HR
                || row.getHrReviewedAt() != null;
        if (!reached || row.getStatus() == NursingEvaluationStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phiếu không thể duyệt ở bước HCNS");
        }
        NursingEvaluationStatus previous = row.getStatus();
        row.setHrReviewer(reviewer);
        row.setHrReviewedAt(Instant.now());
        row.setHrComment(blankToNull(body.getComment()));
        row.setHrSignaturePath(
                approvalSignatureService.snapshotForApproval(reviewer, "nursing-eval", row.getId(), "hr"));
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        if (!approved) {
            row.setStatus(NursingEvaluationStatus.HR_REJECTED);
            nursingEvaluationRepository.save(row);
            notificationService.notifyNursingEvaluationResult(row, false, "HCNS");
            return toMap(row);
        }
        if (previous == NursingEvaluationStatus.PENDING_HR
                || previous == NursingEvaluationStatus.HR_REJECTED) {
            row.setStatus(NursingEvaluationStatus.PENDING_DIRECTOR);
        }
        nursingEvaluationRepository.save(row);
        if (row.getStatus() == NursingEvaluationStatus.PENDING_DIRECTOR) {
            notifyDirectorsPending(row);
        }
        return toMap(row);
    }

    @PreAuthorize("hasAnyRole('ADMIN','DIRECTOR')")
    @Transactional
    public Map<String, Object> directorReview(Long id, NursingEvaluationReviewRequest body) {
        UserAccount reviewer = ensureDirectorOrAdmin();
        NursingEvaluation row = nursingEvaluationRepository.findDetailById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá"));
        boolean reached = row.getStatus() == NursingEvaluationStatus.PENDING_DIRECTOR
                || row.getDirectorReviewedAt() != null;
        if (!reached || row.getStatus() == NursingEvaluationStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phiếu không thể duyệt ở bước Giám đốc");
        }
        row.setDirectorReviewer(reviewer);
        row.setDirectorReviewedAt(Instant.now());
        row.setDirectorComment(blankToNull(body.getComment()));
        row.setDirectorSignaturePath(
                approvalSignatureService.snapshotForApproval(reviewer, "nursing-eval", row.getId(), "director"));
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        if (!approved) {
            row.setStatus(NursingEvaluationStatus.DIRECTOR_REJECTED);
            nursingEvaluationRepository.save(row);
            notificationService.notifyNursingEvaluationResult(row, false, "Giám đốc");
            return toMap(row);
        }
        row.setStatus(NursingEvaluationStatus.APPROVED);
        nursingEvaluationRepository.save(row);
        notificationService.notifyNursingEvaluationResult(row, true, "Giám đốc");
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> cancel(Long id) {
        UserAccount actor = employeeService.currentUser();
        NursingEvaluation row = nursingEvaluationRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá"));
        boolean canCancel = actor.getRole() == UserRole.ADMIN
                || (row.getEvaluator() != null && row.getEvaluator().getId().equals(actor.getId()));
        if (!canCancel) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền thu hồi phiếu này");
        }
        if (row.getStatus() == NursingEvaluationStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phiếu đã thu hồi rồi");
        }
        row.setStatus(NursingEvaluationStatus.CANCELLED);
        nursingEvaluationRepository.save(row);
        return toMap(row);
    }

    private void assertCanCreate(UserAccount actor, Employee emp) {
        if (!NursingBlockClassifier.matches(emp)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Chỉ đánh giá nhân viên khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa");
        }
        if (actor.getRole() == UserRole.ADMIN || EmployeeService.isHeadRole(actor)) {
            return;
        }
        throw new ApiException(HttpStatus.FORBIDDEN,
                "Chỉ Trưởng khoa / ĐDT khoa (khối Điều dưỡng) được lập phiếu đánh giá");
    }

    private void assertCanView(Employee emp) {
        UserAccount current = employeeService.currentUser();
        if (!canViewQuiet(current, emp)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem phiếu đánh giá");
        }
    }

    /**
     * Người xem chỉ với tư cách chính chủ hồ sơ (không phải quyền quản lý).
     * Nhân viên chỉ được xem phiếu đã APPROVED.
     */
    private boolean isSelfViewerOnly(UserAccount current, Employee emp) {
        if (current == null || emp == null) {
            return false;
        }
        if (current.getRole() == UserRole.ADMIN
                || current.getRole() == UserRole.HR
                || EmployeeService.isHr2Role(current)
                || current.getRole() == UserRole.HEAD_NURSING
                || ApprovalAuthority.isDirectorApprover(current)) {
            return false;
        }
        if (EmployeeService.isHeadRole(current)) {
            try {
                employeeService.assertCanAccessEmployee(emp);
                return false;
            } catch (ApiException ignored) {
                // không thuộc khoa — chỉ còn quyền tự xem
            }
        }
        var self = employeeService.linkedEmployee(current);
        return self.isPresent() && self.get().getId().equals(emp.getId());
    }

    private boolean canViewQuiet(UserAccount current, Employee emp) {
        if (current == null) {
            return false;
        }
        if (current.getRole() == UserRole.ADMIN
                || current.getRole() == UserRole.HR
                || EmployeeService.isHr2Role(current)
                || ApprovalAuthority.isDirectorApprover(current)) {
            return NursingBlockClassifier.matches(emp);
        }
        if (current.getRole() == UserRole.HEAD_NURSING) {
            return NursingBlockClassifier.matches(emp);
        }
        if (EmployeeService.isHeadRole(current)) {
            try {
                employeeService.assertCanAccessEmployee(emp);
                return NursingBlockClassifier.matches(emp);
            } catch (ApiException e) {
                return false;
            }
        }
        var self = employeeService.linkedEmployee(current);
        return self.isPresent() && self.get().getId().equals(emp.getId());
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
        if (!ApprovalAuthority.isDirectorApprover(u)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Giám đốc/ADMIN được duyệt bước này");
        }
        return u;
    }

    private void notifyNursingHeadsPending(NursingEvaluation row) {
        for (UserAccount u : userAccountRepository.findByRoleIn(
                List.of(UserRole.HEAD_NURSING, UserRole.ADMIN))) {
            if (!u.isEnabled()) {
                continue;
            }
            if (u.getRole() == UserRole.ADMIN
                    || employeeService.shouldReceiveNursingHeadPendingNotification(u, row.getEmployee())) {
                notificationService.notifyNursingEvaluationPendingNursingHead(u, row);
            }
        }
    }

    private void notifyHrPending(NursingEvaluation row) {
        for (UserAccount u : userAccountRepository.findByRoleIn(List.of(UserRole.HR2, UserRole.HEAD_HR, UserRole.ADMIN))) {
            if (u.isEnabled()) {
                notificationService.notifyNursingEvaluationPendingHr(u, row);
            }
        }
    }

    private void notifyDirectorsPending(NursingEvaluation row) {
        for (UserAccount u : userAccountRepository.findByDirectorApprovalEnabledTrueAndEnabledTrue()) {
            if (u.isEnabled()) {
                notificationService.notifyNursingEvaluationPendingDirector(u, row);
            }
        }
    }

    private record ScoreAgg(BigDecimal total, String grade) {
    }

    private ScoreAgg computeScore(JsonNode groups, Map<String, Object> scores, JsonNode template) {
        BigDecimal base = BigDecimal.ZERO;
        BigDecimal bonus = BigDecimal.ZERO;
        BigDecimal penalty = BigDecimal.ZERO;
        BigDecimal maxBase = BigDecimal.ZERO;
        for (JsonNode g : groups) {
            if (isCouncilCriterion(g)) {
                continue;
            }
            String cid = g.get("id").asText();
            BigDecimal pts = pointsOf(scores.get(cid));
            if (isBonusCriterion(g)) {
                bonus = bonus.add(pts != null ? pts : BigDecimal.ZERO);
            } else if (isPenaltyCriterion(g)) {
                penalty = penalty.add(pts != null ? pts : BigDecimal.ZERO);
            } else {
                if (pts == null) {
                    pts = BigDecimal.ZERO;
                }
                base = base.add(pts);
                maxBase = maxBase.add(maxPointsFromGroup(g));
            }
        }
        if (template.has("baseMaxPoints") && !template.get("baseMaxPoints").isNull()) {
            maxBase = BigDecimal.valueOf(template.get("baseMaxPoints").asDouble());
        }
        BigDecimal total = base.add(bonus).subtract(penalty).setScale(2, RoundingMode.HALF_UP);
        if (total.compareTo(BigDecimal.ZERO) < 0) {
            total = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);
        }
        BigDecimal gradeMax = maxBase.setScale(2, RoundingMode.HALF_UP);
        if (gradeMax.compareTo(BigDecimal.ZERO) <= 0) {
            gradeMax = new BigDecimal("90.00");
        }
        return new ScoreAgg(total, gradeFromTotalScaled(total.min(gradeMax), gradeMax));
    }

    @SuppressWarnings("unchecked")
    private static BigDecimal pointsOf(Object rowObj) {
        if (rowObj instanceof Map<?, ?> raw) {
            return toBigDecimalOrNull(((Map<String, Object>) raw).get("points"));
        }
        return null;
    }

    private Map<String, Object> toSummaryRow(NursingEvaluation n) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("evaluationId", n.getId());
        m.put("employeeId", n.getEmployee().getId());
        m.put("employeeCode", n.getEmployee().getEmployeeCode());
        m.put("fullName", n.getEmployee().getFullName());
        m.put("departmentName",
                n.getEmployee().getDepartment() != null ? n.getEmployee().getDepartment().getName() : "");
        m.put("periodYear", n.getPeriodYear());
        m.put("periodMonth", n.getPeriodMonth());
        m.put("status", n.getStatus() != null ? n.getStatus().name() : null);
        m.put("totalScore", n.getTotalScore());
        m.put("overallGrade", n.getOverallGrade());
        m.put("total100", n.getTotalScore());
        m.put("evaluatorUsername", n.getEvaluator() != null ? n.getEvaluator().getUsername() : "");
        // legacy fields for old summary UI
        m.put("totalTruongKhoa", n.getTotalScore());
        m.put("totalDdt", null);
        m.put("gradeTruongKhoa", n.getOverallGrade());
        m.put("gradeDdt", null);
        m.put("deptAvg70", n.getTotalScore());
        m.put("hdTotal30", null);
        m.put("hdGrade", null);
        return m;
    }

    private Map<String, Object> toMap(NursingEvaluation n) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", n.getId());
        m.put("employeeId", n.getEmployee().getId());
        m.put("employeeCode", n.getEmployee().getEmployeeCode());
        m.put("employeeName", n.getEmployee().getFullName());
        m.put("fullName", n.getEmployee().getFullName());
        m.put("departmentName",
                n.getEmployee().getDepartment() != null ? n.getEmployee().getDepartment().getName() : "");
        m.put("positionTitle",
                n.getEmployee().getPosition() != null ? n.getEmployee().getPosition().getTitle() : "");
        m.put("periodYear", n.getPeriodYear());
        m.put("periodMonth", n.getPeriodMonth());
        m.put("templateCode", n.getTemplateCode());
        m.put("status", n.getStatus() != null ? n.getStatus().name() : null);
        m.put("totalScore", n.getTotalScore());
        m.put("overallGrade", n.getOverallGrade());
        m.put("comments", n.getComments());
        m.put("evaluatorUsername", n.getEvaluator() != null ? n.getEvaluator().getUsername() : "");
        m.put("requestedByUsername", n.getEvaluator() != null ? n.getEvaluator().getUsername() : "");
        m.put("evaluatorSignedAt",
                n.getEvaluatorSignedAt() != null ? n.getEvaluatorSignedAt().toString() : null);
        m.put("evaluatorSignatureUrl", sigUrl(n.getId(), "evaluator", n.getEvaluatorSignaturePath()));
        try {
            m.put("scores", objectMapper.readValue(n.getScoresJson(),
                    new TypeReference<Map<String, Object>>() {
                    }));
        } catch (Exception e) {
            m.put("scores", Map.of());
        }
        m.put("createdAt", n.getCreatedAt() != null ? n.getCreatedAt().toString() : null);
        m.put("updatedAt", n.getUpdatedAt() != null ? n.getUpdatedAt().toString() : null);

        m.put("headReviewerUsername",
                n.getHeadReviewer() != null ? n.getHeadReviewer().getUsername() : null);
        m.put("headComment", n.getHeadComment());
        m.put("headReviewedAt", n.getHeadReviewedAt() != null ? n.getHeadReviewedAt().toString() : null);
        m.put("headSignatureUrl", sigUrl(n.getId(), "nursing-head", n.getHeadSignaturePath()));

        m.put("hrReviewerUsername", n.getHrReviewer() != null ? n.getHrReviewer().getUsername() : null);
        m.put("hrComment", n.getHrComment());
        m.put("hrReviewedAt", n.getHrReviewedAt() != null ? n.getHrReviewedAt().toString() : null);
        m.put("hrSignatureUrl", sigUrl(n.getId(), "hr", n.getHrSignaturePath()));

        m.put("directorReviewerUsername",
                n.getDirectorReviewer() != null ? n.getDirectorReviewer().getUsername() : null);
        m.put("directorComment", n.getDirectorComment());
        m.put("directorReviewedAt",
                n.getDirectorReviewedAt() != null ? n.getDirectorReviewedAt().toString() : null);
        m.put("directorSignatureUrl", sigUrl(n.getId(), "director", n.getDirectorSignaturePath()));

        // legacy
        m.put("totalTruongKhoa", n.getTotalScore());
        m.put("gradeTruongKhoa", n.getOverallGrade());
        return m;
    }

    private static String sigUrl(Long id, String role, String path) {
        if (path == null || path.isBlank()) {
            return null;
        }
        return "/j1-api/v1/approval-signatures/nursing-eval/" + id + "/" + role;
    }

    private Map<String, Set<BigDecimal>> buildAllowedPoints(JsonNode groups) {
        Map<String, Set<BigDecimal>> out = new LinkedHashMap<>();
        for (JsonNode g : groups) {
            if (isCouncilCriterion(g)) {
                continue;
            }
            String cid = g.get("id").asText();
            Set<BigDecimal> pts = new LinkedHashSet<>();
            if (g.has("options") && g.get("options").isArray()) {
                for (JsonNode o : g.get("options")) {
                    if (o.has("points")) {
                        pts.add(BigDecimal.valueOf(o.get("points").asDouble())
                                .setScale(2, RoundingMode.HALF_UP));
                    }
                }
            }
            out.put(cid, pts);
        }
        return out;
    }

    private static boolean isCouncilCriterion(JsonNode g) {
        if (g == null) return false;
        String id = g.has("id") ? g.get("id").asText("") : "";
        String sec = g.has("section") ? g.get("section").asText("") : "";
        return id.startsWith("HD_") || sec.startsWith("HỘI ĐỒNG");
    }

    private static boolean isBonusCriterion(JsonNode g) {
        if (g == null) return false;
        if (g.has("bonus") && g.get("bonus").asBoolean(false)) return true;
        String id = g.has("id") ? g.get("id").asText("") : "";
        return id.startsWith("VI_");
    }

    private static boolean isPenaltyCriterion(JsonNode g) {
        if (g == null) return false;
        if (g.has("penalty") && g.get("penalty").asBoolean(false)) return true;
        String id = g.has("id") ? g.get("id").asText("") : "";
        return id.startsWith("VII_");
    }

    private static BigDecimal maxPointsFromGroup(JsonNode g) {
        if (g.has("maxPoints") && !g.get("maxPoints").isNull()) {
            return BigDecimal.valueOf(g.get("maxPoints").asDouble());
        }
        if (g.has("options") && g.get("options").isArray()) {
            double m = 0;
            for (JsonNode o : g.get("options")) {
                if (o.has("points")) m = Math.max(m, o.get("points").asDouble());
            }
            return BigDecimal.valueOf(m);
        }
        return BigDecimal.ZERO;
    }

    private static boolean containsPoint(Set<BigDecimal> allowed, BigDecimal val) {
        for (BigDecimal a : allowed) {
            if (a.compareTo(val) == 0) {
                return true;
            }
        }
        return false;
    }

    private static BigDecimal toBigDecimalOrNull(Object o) {
        if (o == null) return null;
        if (o instanceof BigDecimal bd) return bd;
        if (o instanceof Number n) {
            return BigDecimal.valueOf(n.doubleValue()).setScale(2, RoundingMode.HALF_UP);
        }
        try {
            return new BigDecimal(o.toString().trim()).setScale(2, RoundingMode.HALF_UP);
        } catch (Exception e) {
            return null;
        }
    }

    public static String gradeFromTotalScaled(BigDecimal total, BigDecimal maxTotal) {
        if (total == null || maxTotal == null || maxTotal.compareTo(BigDecimal.ZERO) <= 0) {
            return "Chưa đạt";
        }
        BigDecimal pct = total.multiply(new BigDecimal("100"))
                .divide(maxTotal, 2, RoundingMode.HALF_UP);
        if (pct.compareTo(new BigDecimal("90")) >= 0) return "Xuất sắc";
        if (pct.compareTo(new BigDecimal("80")) >= 0) return "Tốt";
        if (pct.compareTo(new BigDecimal("65")) >= 0) return "Khá";
        return "Chưa đạt";
    }

    private static String text(JsonNode n, String field) {
        return n.has(field) ? n.get(field).asText() : "";
    }

    private static String blankToNull(String s) {
        if (s == null || s.isBlank()) return null;
        return s.trim();
    }
}
