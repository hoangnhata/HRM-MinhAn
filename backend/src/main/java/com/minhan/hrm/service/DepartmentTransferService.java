package com.minhan.hrm.service;

import com.minhan.hrm.dto.transfer.DepartmentTransferCreateRequest;
import com.minhan.hrm.dto.transfer.DepartmentTransferReviewRequest;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.*;
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
public class DepartmentTransferService {

    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final Set<DepartmentTransferStatus> OPEN = Set.of(
            DepartmentTransferStatus.PENDING_DIRECTOR,
            DepartmentTransferStatus.APPROVED);

    private final DepartmentTransferRequestRepository transferRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeLinkService employeeLinkService;
    private final DepartmentRepository departmentRepository;
    private final PositionRepository positionRepository;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeService employeeService;
    private final NotificationService notificationService;
    private final ApprovalSignatureService approvalSignatureService;

    @Transactional
    public Map<String, Object> create(DepartmentTransferCreateRequest req) {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.HR && actor.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ HCNS/ADMIN được tạo đề nghị luân chuyển");
        }
        Employee emp = employeeRepository.findById(req.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (emp.getStatus() == EmployeeStatus.TERMINATED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không thể luân chuyển nhân viên đã nghỉ việc");
        }
        if (transferRepository.existsByEmployeeAndStatusIn(emp, OPEN)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đang có đề nghị luân chuyển chờ duyệt hoặc chờ ngày hiệu lực");
        }
        Department toDept = departmentRepository.findById(req.getToDepartmentId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban đích"));
        if (emp.getDepartment() != null && emp.getDepartment().getId().equals(toDept.getId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phòng ban đích trùng phòng ban hiện tại");
        }
        if (req.getEffectiveDate() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu ngày luân chuyển");
        }
        Position toPos = null;
        if (req.getToPositionId() != null) {
            toPos = positionRepository.findById(req.getToPositionId())
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy chức vụ đích"));
        }

        DepartmentTransferRequest row = DepartmentTransferRequest.builder()
                .employee(emp)
                .fromDepartment(emp.getDepartment())
                .toDepartment(toDept)
                .toPosition(toPos)
                .effectiveDate(req.getEffectiveDate())
                .reason(req.getReason().trim())
                .status(DepartmentTransferStatus.PENDING_DIRECTOR)
                .requestedBy(actor)
                .build();
        row = transferRepository.save(row);

        notifyDirectorsPending(row);
        notificationService.notifyDepartmentTransferSubmittedToEmployee(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> update(Long id, DepartmentTransferCreateRequest req) {
        UserAccount actor = employeeService.currentUser();
        DepartmentTransferRequest row = transferRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề nghị luân chuyển"));
        RequestEditSupport.ensureRequesterOrAdmin(actor, row.getRequestedBy(),
                "Không có quyền chỉnh sửa đề nghị này");
        RequestEditSupport.ensurePendingStatus(row.getStatus(), "đề nghị luân chuyển");

        Employee emp = row.getEmployee();
        if (!emp.getId().equals(req.getEmployeeId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đổi nhân viên khi chỉnh sửa đề nghị");
        }
        if (transferRepository.findByEmployeeIdOrderByCreatedAtDesc(emp.getId()).stream()
                .anyMatch(r -> !r.getId().equals(id) && OPEN.contains(r.getStatus()))) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Nhân viên đang có đề nghị luân chuyển chờ duyệt hoặc chờ ngày hiệu lực");
        }
        Department toDept = departmentRepository.findById(req.getToDepartmentId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban đích"));
        if (emp.getDepartment() != null && emp.getDepartment().getId().equals(toDept.getId())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phòng ban đích trùng phòng ban hiện tại");
        }
        if (req.getEffectiveDate() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu ngày luân chuyển");
        }
        Position toPos = null;
        if (req.getToPositionId() != null) {
            toPos = positionRepository.findById(req.getToPositionId())
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy chức vụ đích"));
        }

        row.setToDepartment(toDept);
        row.setToPosition(toPos);
        row.setEffectiveDate(req.getEffectiveDate());
        row.setReason(req.getReason().trim());
        row = transferRepository.save(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingDirector() {
        ensureCanViewTransfers();
        return transferRepository.findPendingWithDetails(DepartmentTransferStatus.PENDING_DIRECTOR).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listReviewHistory() {
        ensureCanViewTransfers();
        return transferRepository.findReviewHistoryWithDetails().stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getById(Long id) {
        DepartmentTransferRequest row = transferRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề nghị luân chuyển"));
        ensureCanViewRequest(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listByEmployee(Long employeeId) {
        ensureCanListForEmployee(employeeId);
        return transferRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listRelatedToMe() {
        Employee self = requireSelfEmployee();
        return transferRepository.findByEmployeeIdOrderByCreatedAtDesc(self.getId()).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional
    public Map<String, Object> directorReview(Long id, DepartmentTransferReviewRequest body) {
        UserAccount director = ensureDirectorOrAdmin();
        DepartmentTransferRequest row = transferRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề nghị luân chuyển"));
        if (row.getStatus() != DepartmentTransferStatus.PENDING_DIRECTOR
                && row.getStatus() != DepartmentTransferStatus.REJECTED
                && row.getStatus() != DepartmentTransferStatus.APPROVED) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Đề nghị đã áp dụng hoặc đã hủy nên không thể đổi quyết định");
        }
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setDirectorReviewer(director);
        row.setDirectorReviewedAt(Instant.now());
        row.setDirectorComment(body.getComment() != null && !body.getComment().isBlank()
                ? body.getComment().trim() : null);
        row.setDirectorSignaturePath(
                approvalSignatureService.snapshotForApproval(director, "transfer", row.getId(), "director"));

        if (!approved) {
            row.setStatus(DepartmentTransferStatus.REJECTED);
            transferRepository.save(row);
            notificationService.notifyDepartmentTransferResult(row, false);
            return toMap(row);
        }

        LocalDate today = LocalDate.now(VN);
        if (!row.getEffectiveDate().isAfter(today)) {
            applyTransfer(row);
        } else {
            row.setStatus(DepartmentTransferStatus.APPROVED);
            transferRepository.save(row);
            notificationService.notifyDepartmentTransferResult(row, true);
        }
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> cancel(Long id) {
        UserAccount actor = employeeService.currentUser();
        DepartmentTransferRequest row = transferRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đề nghị luân chuyển"));
        boolean canCancel = actor.getRole() == UserRole.ADMIN
                || actor.getRole() == UserRole.HR
                || (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(actor.getId()));
        if (!canCancel) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền hủy đề nghị này");
        }
        if (row.getStatus() == DepartmentTransferStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đề nghị đã thu hồi rồi");
        }
        if (row.getStatus() == DepartmentTransferStatus.APPLIED) {
            Employee emp = row.getEmployee();
            emp.setDepartment(row.getFromDepartment());
            employeeRepository.save(emp);
            row.setAppliedAt(null);
        }
        row.setStatus(DepartmentTransferStatus.CANCELLED);
        transferRepository.save(row);
        return toMap(row);
    }

    /** Scheduler / áp dụng ngay khi đến ngày. */
    @Transactional
    public int applyDueTransfers() {
        LocalDate today = LocalDate.now(VN);
        List<DepartmentTransferRequest> due = transferRepository.findDueToApply(today);
        int n = 0;
        for (DepartmentTransferRequest row : due) {
            try {
                applyTransfer(row);
                n++;
            } catch (Exception e) {
                log.warn("Apply transfer #{} failed: {}", row.getId(), e.getMessage());
            }
        }
        return n;
    }

    private void applyTransfer(DepartmentTransferRequest row) {
        if (row.getStatus() == DepartmentTransferStatus.APPLIED) {
            return;
        }
        Employee emp = row.getEmployee();
        emp.setDepartment(row.getToDepartment());
        if (row.getToPosition() != null) {
            emp.setPosition(row.getToPosition());
        }
        employeeRepository.save(emp);
        row.setStatus(DepartmentTransferStatus.APPLIED);
        row.setAppliedAt(Instant.now());
        transferRepository.save(row);
        notificationService.notifyDepartmentTransferApplied(row);
    }

    private void notifyDirectorsPending(DepartmentTransferRequest row) {
        List<UserAccount> directors = userAccountRepository.findByDirectorApprovalEnabledTrueAndEnabledTrue();
        for (UserAccount u : directors) {
            if (!u.isEnabled()) {
                continue;
            }
            notificationService.notifyDepartmentTransferPending(u, row);
        }
    }

    private UserAccount ensureDirectorOrAdmin() {
        UserAccount u = employeeService.currentUser();
        if (!com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(u)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Giám đốc/ADMIN được duyệt luân chuyển");
        }
        return u;
    }

    private void ensureCanViewTransfers() {
        UserAccount u = employeeService.currentUser();
        if (!com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(u)
                && u.getRole() != UserRole.HR) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đơn luân chuyển");
        }
    }

    private void ensureCanViewRequest(DepartmentTransferRequest row) {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() == UserRole.HR || com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(u)) {
            return;
        }
        if (u.getRole() == UserRole.EMPLOYEE) {
            Long selfId = actorEmployeeId(u);
            if (selfId != null && row.getEmployee().getId().equals(selfId)) {
                return;
            }
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đơn luân chuyển");
    }

    private void ensureCanListForEmployee(Long employeeId) {
        UserAccount actor = employeeService.currentUser();
        UserRole role = actor.getRole();
        if (role == UserRole.HR || com.minhan.hrm.security.ApprovalAuthority.isDirectorApprover(actor)) {
            return;
        }
        if (role == UserRole.EMPLOYEE) {
            Long selfId = actorEmployeeId(actor);
            if (selfId != null && selfId.equals(employeeId)) {
                return;
            }
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đơn luân chuyển");
    }

    private Employee requireSelfEmployee() {
        UserAccount actor = employeeService.currentUser();
        return employeeLinkService.findLinkedEmployee(actor)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản chưa liên kết nhân viên"));
    }

    private Long actorEmployeeId(UserAccount actor) {
        return employeeLinkService.findLinkedEmployee(actor).map(Employee::getId).orElse(null);
    }

    private Map<String, Object> toMap(DepartmentTransferRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", r.getEmployee().getId());
        m.put("employeeCode", r.getEmployee().getEmployeeCode());
        m.put("employeeName", r.getEmployee().getFullName());
        m.put("positionTitle", r.getEmployee().getPosition() != null
                ? r.getEmployee().getPosition().getTitle() : null);
        m.put("fromDepartmentId", r.getFromDepartment().getId());
        m.put("fromDepartmentName", r.getFromDepartment().getName());
        m.put("toDepartmentId", r.getToDepartment().getId());
        m.put("toDepartmentName", r.getToDepartment().getName());
        m.put("toPositionId", r.getToPosition() != null ? r.getToPosition().getId() : null);
        m.put("toPositionTitle", r.getToPosition() != null ? r.getToPosition().getTitle() : null);
        m.put("effectiveDate", r.getEffectiveDate().toString());
        m.put("reason", r.getReason());
        m.put("status", r.getStatus().name());
        m.put("requestedByUsername", r.getRequestedBy() != null ? r.getRequestedBy().getUsername() : null);
        m.put("directorReviewerUsername",
                r.getDirectorReviewer() != null ? r.getDirectorReviewer().getUsername() : null);
        m.put("directorComment", r.getDirectorComment());
        m.put("directorReviewedAt", r.getDirectorReviewedAt() != null ? r.getDirectorReviewedAt().toString() : null);
        m.put("directorSignatureUrl", r.getDirectorSignaturePath() != null && !r.getDirectorSignaturePath().isBlank()
                ? "/j1-api/v1/approval-signatures/transfer/" + r.getId() + "/director" : null);
        m.put("appliedAt", r.getAppliedAt() != null ? r.getAppliedAt().toString() : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }
}
