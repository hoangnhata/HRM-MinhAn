package com.minhan.hrm.service;

import com.minhan.hrm.dto.mainduty.MainDutyAuthorizationCreateRequest;
import com.minhan.hrm.dto.mainduty.MainDutyAuthorizationReviewRequest;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.MainDutyAuthorizationRequestRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.service.support.RequestEditSupport;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class MainDutyAuthorizationService {

    private static final Set<MainDutyAuthorizationStatus> OPEN = Set.of(
            MainDutyAuthorizationStatus.PENDING_HEAD,
            MainDutyAuthorizationStatus.PENDING_NURSING_HEAD,
            MainDutyAuthorizationStatus.PENDING_DIRECTOR);
    private static final DateTimeFormatter VN_DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final MainDutyAuthorizationRequestRepository requestRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeLinkService employeeLinkService;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeService employeeService;
    private final NotificationService notificationService;
    private final ApprovalSignatureService approvalSignatureService;
    private final ProbationFormTypeResolver formTypeResolver;

    @Transactional
    public Map<String, Object> create(MainDutyAuthorizationCreateRequest req) {
        UserAccount actor = ensureCanCreate(req);
        Employee emp = employeeRepository.findById(req.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (emp.getStatus() == EmployeeStatus.TERMINATED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không lập đơn trực chính cho nhân viên đã nghỉ việc");
        }
        if (emp.isMainDutyAuthorized()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Nhân viên đã được cấp quyền trực chính");
        }
        if (requestRepository.existsByEmployeeAndStatusIn(emp, OPEN)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đang có đơn trực chính chờ duyệt");
        }
        if (req.getEffectiveFrom() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu ngày hiệu lực");
        }
        if (req.getAccompanyingTo().isBefore(req.getAccompanyingFrom())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Ngày kết thúc đồng hành phải sau hoặc bằng ngày bắt đầu");
        }

        MainDutyFormType formType = resolveMainDutyFormType(emp);
        boolean nursingBlock = NursingBlockClassifier.matches(emp);
        boolean skipHead = actor.getRole() == UserRole.ADMIN
                || EmployeeService.isHeadRole(actor);

        MainDutyAuthorizationRequest.MainDutyAuthorizationRequestBuilder builder =
                MainDutyAuthorizationRequest.builder()
                        .employee(emp)
                        .formType(formType)
                        .accompanyingFrom(req.getAccompanyingFrom())
                        .accompanyingTo(req.getAccompanyingTo())
                        .effectiveFrom(req.getEffectiveFrom())
                        .phone(blankToNull(req.getPhone()))
                        .address(blankToNull(req.getAddress()))
                        .gender(blankToNull(req.getGender()))
                        .degree(blankToNull(req.getDegree()))
                        .reason(blankToNull(req.getReason()))
                        .requestedBy(actor);

        if (skipHead) {
            builder.headReviewer(actor)
                    .headReviewedAt(Instant.now())
                    .headComment("Trưởng khoa lập phiếu");
            if (nursingBlock) {
                builder.status(MainDutyAuthorizationStatus.PENDING_NURSING_HEAD);
            } else {
                builder.status(MainDutyAuthorizationStatus.PENDING_DIRECTOR);
            }
        } else {
            builder.status(MainDutyAuthorizationStatus.PENDING_HEAD);
        }

        MainDutyAuthorizationRequest row = requestRepository.save(builder.build());

        if (skipHead && nursingBlock) {
            notifyNursingHeadsPending(row);
        } else if (skipHead) {
            notifyDirectorsPending(row);
            notificationService.notifyMainDutyForwarded(row);
        } else {
            notifyDepartmentHeads(row);
        }
        notificationService.notifyMainDutySubmittedToEmployee(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> update(Long id, MainDutyAuthorizationCreateRequest req) {
        UserAccount actor = employeeService.currentUser();
        MainDutyAuthorizationRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn trực chính"));
        RequestEditSupport.ensureRequesterOrAdmin(actor, row.getRequestedBy(),
                "Không có quyền chỉnh sửa đơn này");
        RequestEditSupport.ensurePendingStatus(row.getStatus(), "đơn trực chính");

        Employee emp = row.getEmployee();
        if (!emp.getId().equals(req.getEmployeeId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đổi nhân viên khi chỉnh sửa đơn");
        }
        if (requestRepository.findByEmployeeIdOrderByCreatedAtDesc(emp.getId()).stream()
                .anyMatch(r -> !r.getId().equals(id) && OPEN.contains(r.getStatus()))) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đang có đơn trực chính chờ duyệt");
        }
        if (req.getEffectiveFrom() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu ngày hiệu lực");
        }
        if (req.getAccompanyingTo().isBefore(req.getAccompanyingFrom())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Ngày kết thúc đồng hành phải sau hoặc bằng ngày bắt đầu");
        }

        row.setAccompanyingFrom(req.getAccompanyingFrom());
        row.setAccompanyingTo(req.getAccompanyingTo());
        row.setEffectiveFrom(req.getEffectiveFrom());
        row.setPhone(blankToNull(req.getPhone()));
        row.setAddress(blankToNull(req.getAddress()));
        row.setGender(blankToNull(req.getGender()));
        row.setDegree(blankToNull(req.getDegree()));
        row.setReason(blankToNull(req.getReason()));
        row = requestRepository.save(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingHead() {
        UserAccount actor = ensureCanView();
        return requestRepository.findPendingWithDetails(MainDutyAuthorizationStatus.PENDING_HEAD).stream()
                .filter(row -> employeeService.matchesHeadScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingNursingHead() {
        UserAccount actor = ensureNursingHeadOrAdmin();
        return requestRepository.findPendingWithDetails(MainDutyAuthorizationStatus.PENDING_NURSING_HEAD).stream()
                .filter(row -> actor.getRole() == UserRole.ADMIN
                        || NursingBlockClassifier.matches(row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingHr() {
        UserAccount actor = ensureCanView();
        return requestRepository.findPendingWithDetails(MainDutyAuthorizationStatus.PENDING_HR).stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingDirector() {
        UserAccount actor = ensureCanView();
        return requestRepository.findPendingWithDetails(MainDutyAuthorizationStatus.PENDING_DIRECTOR).stream()
                .filter(row -> employeeService.matchesHrReviewScope(actor, row.getEmployee()))
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listHistory() {
        UserAccount actor = ensureCanView();
        return requestRepository.findReviewHistoryWithDetails().stream()
                .filter(row -> {
                    if (actor.getRole() == UserRole.HEAD_NURSING) {
                        if (!employeeService.matchesNursingBlockScope(actor, row.getEmployee())) {
                            return false;
                        }
                        return row.getNursingHeadReviewedAt() != null
                                || row.getStatus() == MainDutyAuthorizationStatus.NURSING_HEAD_REJECTED;
                    }
                    return employeeService.matchesHrReviewScope(actor, row.getEmployee());
                })
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
    public List<Map<String, Object>> listByEmployee(Long employeeId) {
        ensureCanListForEmployee(employeeId);
        return requestRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listRelatedToMe() {
        Employee self = requireSelfEmployee();
        return requestRepository.findByEmployeeIdOrderByCreatedAtDesc(self.getId()).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getById(Long id) {
        MainDutyAuthorizationRequest row = requestRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn trực chính"));
        ensureCanViewDetail(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> headReview(Long id, MainDutyAuthorizationReviewRequest body) {
        UserAccount head = ensureHeadOrAdmin();
        MainDutyAuthorizationRequest row = requestRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn trực chính"));
        boolean hasReachedHead = row.getStatus() == MainDutyAuthorizationStatus.PENDING_HEAD
                || row.getHeadReviewedAt() != null;
        if (!hasReachedHead || row.getStatus() == MainDutyAuthorizationStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn đã hủy nên không thể đổi quyết định Trưởng khoa");
        }
        MainDutyAuthorizationStatus previousStatus = row.getStatus();
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setHeadReviewer(head);
        row.setHeadReviewedAt(Instant.now());
        row.setHeadComment(blankToNull(body.getComment()));
        row.setHeadSignaturePath(
                approvalSignatureService.snapshotForApproval(head, "main-duty", row.getId(), "head"));

        if (!approved) {
            row.setStatus(MainDutyAuthorizationStatus.HEAD_REJECTED);
            requestRepository.save(row);
            refreshMainDutyAuthorization(row.getEmployee());
            notificationService.notifyMainDutyResult(row, false, "Trưởng khoa");
            return toMap(row);
        }

        if (previousStatus == MainDutyAuthorizationStatus.PENDING_HEAD
                || previousStatus == MainDutyAuthorizationStatus.HEAD_REJECTED) {
            if (NursingBlockClassifier.matches(row.getEmployee())) {
                row.setStatus(MainDutyAuthorizationStatus.PENDING_NURSING_HEAD);
            } else {
                row.setStatus(MainDutyAuthorizationStatus.PENDING_DIRECTOR);
            }
        }
        requestRepository.save(row);
        if (row.getStatus() == MainDutyAuthorizationStatus.PENDING_NURSING_HEAD) {
            notifyNursingHeadsPending(row);
        } else if (row.getStatus() == MainDutyAuthorizationStatus.PENDING_DIRECTOR) {
            notifyDirectorsPending(row);
            notificationService.notifyMainDutyForwarded(row);
        }
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> nursingHeadReview(Long id, MainDutyAuthorizationReviewRequest body) {
        UserAccount nursingHead = ensureNursingHeadOrAdmin();
        MainDutyAuthorizationRequest row = requestRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn trực chính"));
        boolean hasReachedNursingHead = row.getStatus() == MainDutyAuthorizationStatus.PENDING_NURSING_HEAD
                || row.getNursingHeadReviewedAt() != null;
        if (!hasReachedNursingHead || row.getStatus() == MainDutyAuthorizationStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn đã hủy nên không thể đổi quyết định Trưởng phòng Điều dưỡng");
        }
        MainDutyAuthorizationStatus previousStatus = row.getStatus();
        if (nursingHead.getRole() == UserRole.HEAD_NURSING
                && !NursingBlockClassifier.matches(row.getEmployee())) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ duyệt đơn trực chính của khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa");
        }
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setNursingHeadReviewer(nursingHead);
        row.setNursingHeadReviewedAt(Instant.now());
        row.setNursingHeadComment(blankToNull(body.getComment()));
        row.setNursingHeadSignaturePath(
                approvalSignatureService.snapshotForApproval(
                        nursingHead, "main-duty", row.getId(), "nursing-head"));

        if (!approved) {
            row.setStatus(MainDutyAuthorizationStatus.NURSING_HEAD_REJECTED);
            requestRepository.save(row);
            refreshMainDutyAuthorization(row.getEmployee());
            notificationService.notifyMainDutyResult(row, false, "Trưởng phòng Điều dưỡng");
            return toMap(row);
        }

        if (previousStatus == MainDutyAuthorizationStatus.PENDING_NURSING_HEAD
                || previousStatus == MainDutyAuthorizationStatus.NURSING_HEAD_REJECTED) {
            row.setStatus(MainDutyAuthorizationStatus.PENDING_DIRECTOR);
        }
        requestRepository.save(row);
        if (row.getStatus() == MainDutyAuthorizationStatus.PENDING_DIRECTOR) {
            notifyDirectorsPending(row);
            notificationService.notifyMainDutyForwarded(row);
        }
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, MainDutyAuthorizationReviewRequest body) {
        throw new ApiException(HttpStatus.GONE,
                "Quy trình mới bỏ bước HCNS — đơn trực chính gửi thẳng Giám đốc duyệt");
    }

    @Transactional
    public Map<String, Object> directorReview(Long id, MainDutyAuthorizationReviewRequest body) {
        UserAccount director = ensureDirectorOrAdmin();
        MainDutyAuthorizationRequest row = requestRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn trực chính"));
        boolean hasReachedDirector = row.getStatus() == MainDutyAuthorizationStatus.PENDING_DIRECTOR
                || row.getDirectorReviewedAt() != null;
        if (!hasReachedDirector || row.getStatus() == MainDutyAuthorizationStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đơn đã hủy nên không thể đổi quyết định Giám đốc");
        }
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setDirectorReviewer(director);
        row.setDirectorReviewedAt(Instant.now());
        row.setDirectorComment(blankToNull(body.getComment()));
        row.setDirectorSignaturePath(
                approvalSignatureService.snapshotForApproval(director, "main-duty", row.getId(), "director"));

        if (!approved) {
            row.setStatus(MainDutyAuthorizationStatus.DIRECTOR_REJECTED);
            requestRepository.save(row);
            refreshMainDutyAuthorization(row.getEmployee());
            notificationService.notifyMainDutyResult(row, false, "Giám đốc");
            return toMap(row);
        }

        row.setStatus(MainDutyAuthorizationStatus.APPROVED);
        requestRepository.save(row);

        Employee emp = row.getEmployee();
        emp.setMainDutyAuthorized(true);
        employeeRepository.save(emp);

        notificationService.notifyMainDutyResult(row, true, "Giám đốc");
        return toMap(row);
    }

    private void refreshMainDutyAuthorization(Employee employee) {
        boolean stillAuthorized = requestRepository.existsByEmployeeAndStatusIn(
                employee, Set.of(MainDutyAuthorizationStatus.APPROVED));
        employee.setMainDutyAuthorized(stillAuthorized);
        employeeRepository.save(employee);
    }

    @Transactional
    public Map<String, Object> cancel(Long id) {
        UserAccount actor = employeeService.currentUser();
        MainDutyAuthorizationRequest row = requestRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn trực chính"));
        boolean canCancel = actor.getRole() == UserRole.ADMIN
                || (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(actor.getId()));
        if (!canCancel) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền hủy đơn này");
        }
        if (row.getStatus() == MainDutyAuthorizationStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn đã thu hồi rồi");
        }
        MainDutyAuthorizationStatus previous = row.getStatus();
        row.setStatus(MainDutyAuthorizationStatus.CANCELLED);
        requestRepository.save(row);
        if (previous == MainDutyAuthorizationStatus.APPROVED) {
            refreshMainDutyAuthorization(row.getEmployee());
        }
        return toMap(row);
    }

    private MainDutyFormType resolveMainDutyFormType(Employee emp) {
        return switch (formTypeResolver.resolve(emp)) {
            case DOCTOR -> MainDutyFormType.DOCTOR;
            case NURSE -> MainDutyFormType.NURSE;
            case STAFF -> throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Chỉ bác sĩ hoặc điều dưỡng được làm đơn trực chính");
        };
    }

    private UserAccount ensureCanCreate(MainDutyAuthorizationCreateRequest req) {
        UserAccount actor = employeeService.currentUser();
        UserRole role = actor.getRole();
        if (role == UserRole.ADMIN || (role != null && role.isHeadDepartment())) {
            return actor;
        }
        throw new ApiException(HttpStatus.FORBIDDEN,
                "Chỉ Trưởng khoa hoặc ADMIN được lập đơn trực chính");
    }

    private void notifyHrPending(MainDutyAuthorizationRequest row) {
        userAccountRepository.findByRoleIn(List.of(UserRole.HR2, UserRole.HEAD_HR, UserRole.ADMIN)).stream()
                .filter(UserAccount::isEnabled)
                .forEach(u -> notificationService.notifyMainDutyPendingHr(u, row));
    }

    private void notifyDirectorsPending(MainDutyAuthorizationRequest row) {
        List<UserAccount> directors = userAccountRepository.findByDirectorApprovalEnabledTrueAndEnabledTrue();
        for (UserAccount u : directors) {
            if (u.isEnabled()) {
                notificationService.notifyMainDutyPendingDirector(u, row);
            }
        }
    }

    private void notifyNursingHeadsPending(MainDutyAuthorizationRequest row) {
        userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HEAD_NURSING)).stream()
                .filter(u -> employeeService.shouldReceiveNursingHeadPendingNotification(u, row.getEmployee()))
                .forEach(u -> notificationService.notifyMainDutyPendingNursingHead(u, row));
    }

    private void notifyDepartmentHeads(MainDutyAuthorizationRequest row) {
        Employee emp = row.getEmployee();
        for (UserAccount u : userAccountRepository.findByRoleIn(
                List.of(UserRole.ADMIN, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_HR))) {
            if (employeeService.shouldReceiveHeadPendingNotification(u, emp)) {
                notificationService.notifyMainDutyPendingHead(u, row);
            }
        }
    }

    private UserAccount ensureHeadOrAdmin() {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && !EmployeeService.isHeadRole(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Trưởng khoa/ADMIN được duyệt bước này");
        }
        return actor;
    }

    private UserAccount ensureNursingHeadOrAdmin() {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN && actor.getRole() != UserRole.HEAD_NURSING) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ Trưởng phòng Điều dưỡng/ADMIN được duyệt bước này");
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
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách đơn trực chính");
        }
        return actor;
    }

    private void ensureCanViewDetail(MainDutyAuthorizationRequest row) {
        UserAccount actor = employeeService.currentUser();
        UserRole role = actor.getRole();
        if ((role != null && role.isHr2()) || com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(actor)
                || (role != null && role.isHeadDepartment())) {
            return;
        }
        if (role == UserRole.HEAD_NURSING) {
            if (employeeService.matchesNursingBlockScope(actor, row.getEmployee())) {
                return;
            }
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ xem đơn trực chính của khối Điều dưỡng");
        }
        if (role == UserRole.EMPLOYEE) {
            Long selfId = actorEmployeeId(actor);
            if (selfId != null && row.getEmployee().getId().equals(selfId)) {
                return;
            }
            if (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(actor.getId())) {
                return;
            }
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đơn này");
    }

    private Long actorEmployeeId(UserAccount actor) {
        return employeeLinkService.findLinkedEmployee(actor).map(Employee::getId).orElse(null);
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
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ xem đơn trực chính của khối Điều dưỡng");
        }
        if (role == UserRole.EMPLOYEE) {
            Long selfId = actorEmployeeId(actor);
            if (selfId != null && selfId.equals(employeeId)) {
                return;
            }
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách đơn trực chính");
    }

    private Employee requireSelfEmployee() {
        UserAccount actor = employeeService.currentUser();
        return employeeLinkService.findLinkedEmployee(actor)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản chưa liên kết nhân viên"));
    }

    private Map<String, Object> toMap(MainDutyAuthorizationRequest r) {
        Employee e = r.getEmployee();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", e.getId());
        m.put("employeeCode", e.getEmployeeCode());
        m.put("employeeName", e.getFullName());
        m.put("dateOfBirth", e.getDateOfBirth() != null ? e.getDateOfBirth().toString() : null);
        m.put("positionTitle", e.getPosition() != null ? e.getPosition().getTitle() : null);
        m.put("departmentName", e.getDepartment() != null ? e.getDepartment().getName() : null);
        m.put("formType", r.getFormType().name());
        m.put("formTypeLabel", formTypeLabel(r.getFormType()));
        m.put("accompanyingFrom", r.getAccompanyingFrom() != null ? r.getAccompanyingFrom().toString() : null);
        m.put("accompanyingTo", r.getAccompanyingTo() != null ? r.getAccompanyingTo().toString() : null);
        m.put("accompanyingPeriod", formatPeriod(r.getAccompanyingFrom(), r.getAccompanyingTo()));
        m.put("effectiveFrom", r.getEffectiveFrom() != null ? r.getEffectiveFrom().toString() : null);
        m.put("phone", r.getPhone());
        m.put("address", r.getAddress());
        m.put("gender", r.getGender());
        m.put("degree", r.getDegree());
        m.put("reason", r.getReason());
        m.put("status", r.getStatus().name());
        m.put("requestedByUsername", r.getRequestedBy() != null ? r.getRequestedBy().getUsername() : null);
        m.put("headReviewerUsername", r.getHeadReviewer() != null ? r.getHeadReviewer().getUsername() : null);
        m.put("headComment", r.getHeadComment());
        m.put("headReviewedAt", r.getHeadReviewedAt() != null ? r.getHeadReviewedAt().toString() : null);
        m.put("headSignatureUrl", r.getHeadSignaturePath() != null && !r.getHeadSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/main-duty/" + r.getId() + "/head" : null);
        m.put("nursingHeadReviewerUsername",
                r.getNursingHeadReviewer() != null ? r.getNursingHeadReviewer().getUsername() : null);
        m.put("nursingHeadComment", r.getNursingHeadComment());
        m.put("nursingHeadReviewedAt",
                r.getNursingHeadReviewedAt() != null ? r.getNursingHeadReviewedAt().toString() : null);
        m.put("nursingHeadSignatureUrl",
                r.getNursingHeadSignaturePath() != null && !r.getNursingHeadSignaturePath().isBlank()
                        ? "/j1-api/v1/approval-signatures/main-duty/" + r.getId() + "/nursing-head" : null);
        m.put("hrReviewerUsername", r.getHrReviewer() != null ? r.getHrReviewer().getUsername() : null);
        m.put("hrComment", r.getHrComment());
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : null);
        m.put("hrSignatureUrl", r.getHrSignaturePath() != null && !r.getHrSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/main-duty/" + r.getId() + "/hr" : null);
        m.put("directorReviewerUsername",
                r.getDirectorReviewer() != null ? r.getDirectorReviewer().getUsername() : null);
        m.put("directorComment", r.getDirectorComment());
        m.put("directorReviewedAt",
                r.getDirectorReviewedAt() != null ? r.getDirectorReviewedAt().toString() : null);
        m.put("directorSignatureUrl",
                r.getDirectorSignaturePath() != null && !r.getDirectorSignaturePath().isBlank()
                        ? "/j1-api/v1/approval-signatures/main-duty/" + r.getId() + "/director" : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }

    private static String formTypeLabel(MainDutyFormType formType) {
        return switch (formType) {
            case DOCTOR -> "Bác sĩ";
            case NURSE -> "Điều dưỡng";
        };
    }

    private static String formatPeriod(LocalDate from, LocalDate to) {
        if (from == null || to == null) {
            return null;
        }
        if (from.equals(to)) {
            return from.format(VN_DATE);
        }
        return from.format(VN_DATE) + " – " + to.format(VN_DATE);
    }

    private static String blankToNull(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        return s.trim();
    }
}
