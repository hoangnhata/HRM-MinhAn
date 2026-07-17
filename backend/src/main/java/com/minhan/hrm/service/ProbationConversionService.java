package com.minhan.hrm.service;

import com.minhan.hrm.dto.probation.ProbationConversionCreateRequest;
import com.minhan.hrm.dto.probation.ProbationConversionReviewRequest;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.ProbationConversionRequestRepository;
import com.minhan.hrm.repository.UserAccountRepository;
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
            ProbationConversionStatus.PENDING_HR,
            ProbationConversionStatus.PENDING_DIRECTOR,
            ProbationConversionStatus.APPROVED);

    private final ProbationConversionRequestRepository conversionRepository;
    private final EmployeeRepository employeeRepository;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeService employeeService;
    private final NotificationService notificationService;

    @Transactional
    public Map<String, Object> create(ProbationConversionCreateRequest req) {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && actor.getRole() != UserRole.HEAD_DEPARTMENT
                && actor.getRole() != UserRole.HEAD_NURSING) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ Trưởng khoa/phòng, Điều dưỡng trưởng hoặc ADMIN được lập đơn chuyển chính thức");
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

        ProbationConversionRequest row = ProbationConversionRequest.builder()
                .employee(emp)
                .officialDate(req.getOfficialDate())
                .reason(req.getReason().trim())
                .status(ProbationConversionStatus.PENDING_HR)
                .requestedBy(actor)
                .build();
        row = conversionRepository.save(row);
        notifyHrPending(row);
        return toMap(row);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingHr() {
        ensureCanViewAsHrOrAdminOrDirector();
        return conversionRepository.findPendingWithDetails(ProbationConversionStatus.PENDING_HR).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listPendingDirector() {
        ensureCanViewAsHrOrAdminOrDirector();
        return conversionRepository.findPendingWithDetails(ProbationConversionStatus.PENDING_DIRECTOR).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listReviewHistory() {
        ensureCanViewAsHrOrAdminOrDirector();
        return conversionRepository.findReviewHistoryWithDetails().stream()
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
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && actor.getRole() != UserRole.HR
                && actor.getRole() != UserRole.DIRECTOR
                && actor.getRole() != UserRole.HEAD_DEPARTMENT
                && actor.getRole() != UserRole.HEAD_NURSING) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem");
        }
        return conversionRepository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional
    public Map<String, Object> hrReview(Long id, ProbationConversionReviewRequest body) {
        UserAccount hr = ensureHrOrAdmin();
        ProbationConversionRequest row = conversionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn chuyển chính thức"));
        if (row.getStatus() != ProbationConversionStatus.PENDING_HR) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn không còn chờ HCNS duyệt");
        }
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setHrReviewer(hr);
        row.setHrReviewedAt(Instant.now());
        row.setHrComment(blankToNull(body.getComment()));

        if (!approved) {
            row.setStatus(ProbationConversionStatus.HR_REJECTED);
            conversionRepository.save(row);
            notificationService.notifyProbationConversionResult(row, false, "HCNS");
            return toMap(row);
        }

        row.setStatus(ProbationConversionStatus.PENDING_DIRECTOR);
        conversionRepository.save(row);
        notifyDirectorsPending(row);
        notificationService.notifyProbationConversionForwardedToDirector(row);
        return toMap(row);
    }

    @Transactional
    public Map<String, Object> directorReview(Long id, ProbationConversionReviewRequest body) {
        UserAccount director = ensureDirectorOrAdmin();
        ProbationConversionRequest row = conversionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn chuyển chính thức"));
        if (row.getStatus() != ProbationConversionStatus.PENDING_DIRECTOR) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đơn không còn chờ Giám đốc duyệt");
        }
        boolean approved = Boolean.TRUE.equals(body.getApproved());
        row.setDirectorReviewer(director);
        row.setDirectorReviewedAt(Instant.now());
        row.setDirectorComment(blankToNull(body.getComment()));

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
        if (row.getStatus() != ProbationConversionStatus.PENDING_HR
                && row.getStatus() != ProbationConversionStatus.PENDING_DIRECTOR
                && row.getStatus() != ProbationConversionStatus.APPROVED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ hủy được đơn đang chờ duyệt hoặc chờ ngày hiệu lực");
        }
        row.setStatus(ProbationConversionStatus.CANCELLED);
        conversionRepository.save(row);
        return toMap(row);
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

    private void notifyHrPending(ProbationConversionRequest row) {
        List<UserAccount> hrs = userAccountRepository.findByRoleIn(List.of(UserRole.HR, UserRole.ADMIN));
        for (UserAccount u : hrs) {
            if (!u.isEnabled()) {
                continue;
            }
            notificationService.notifyProbationConversionPendingHr(u, row);
        }
    }

    private void notifyDirectorsPending(ProbationConversionRequest row) {
        List<UserAccount> directors = userAccountRepository.findByRoleIn(List.of(UserRole.DIRECTOR));
        if (directors.isEmpty()) {
            directors = userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN));
        }
        for (UserAccount u : directors) {
            if (!u.isEnabled()) {
                continue;
            }
            notificationService.notifyProbationConversionPendingDirector(u, row);
        }
    }

    private UserAccount ensureHrOrAdmin() {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() != UserRole.HR && u.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ HCNS/ADMIN được duyệt bước này");
        }
        return u;
    }

    private UserAccount ensureDirectorOrAdmin() {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() != UserRole.DIRECTOR && u.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Giám đốc/ADMIN được duyệt bước này");
        }
        return u;
    }

    private void ensureCanViewAsHrOrAdminOrDirector() {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() != UserRole.HR
                && u.getRole() != UserRole.ADMIN
                && u.getRole() != UserRole.DIRECTOR) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem danh sách duyệt");
        }
    }

    private void ensureCanViewRequest(ProbationConversionRequest row) {
        UserAccount u = employeeService.currentUser();
        if (u.getRole() == UserRole.ADMIN
                || u.getRole() == UserRole.HR
                || u.getRole() == UserRole.DIRECTOR) {
            return;
        }
        if (row.getRequestedBy() != null && row.getRequestedBy().getId().equals(u.getId())) {
            return;
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đơn này");
    }

    private static String blankToNull(String s) {
        return s != null && !s.isBlank() ? s.trim() : null;
    }

    private Map<String, Object> toMap(ProbationConversionRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", r.getEmployee().getId());
        m.put("employeeCode", r.getEmployee().getEmployeeCode());
        m.put("employeeName", r.getEmployee().getFullName());
        m.put("employeeStatus", r.getEmployee().getStatus() != null ? r.getEmployee().getStatus().name() : null);
        m.put("departmentId", r.getEmployee().getDepartment() != null ? r.getEmployee().getDepartment().getId() : null);
        m.put("departmentName",
                r.getEmployee().getDepartment() != null ? r.getEmployee().getDepartment().getName() : null);
        m.put("officialDate", r.getOfficialDate().toString());
        m.put("reason", r.getReason());
        m.put("status", r.getStatus().name());
        m.put("requestedByUsername", r.getRequestedBy() != null ? r.getRequestedBy().getUsername() : null);
        m.put("hrReviewerUsername", r.getHrReviewer() != null ? r.getHrReviewer().getUsername() : null);
        m.put("hrComment", r.getHrComment());
        m.put("hrReviewedAt", r.getHrReviewedAt() != null ? r.getHrReviewedAt().toString() : null);
        m.put("directorReviewerUsername",
                r.getDirectorReviewer() != null ? r.getDirectorReviewer().getUsername() : null);
        m.put("directorComment", r.getDirectorComment());
        m.put("directorReviewedAt", r.getDirectorReviewedAt() != null ? r.getDirectorReviewedAt().toString() : null);
        m.put("appliedAt", r.getAppliedAt() != null ? r.getAppliedAt().toString() : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }
}
