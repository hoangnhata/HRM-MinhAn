package com.minhan.hrm.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.dto.qtkt.QtktEvaluationUpsertRequest;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.QtktEvaluationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class QtktEvaluationService {

    private final QtktEvaluationRepository evaluationRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeService employeeService;
    private final DepartmentService departmentService;
    private final QtktTemplateService templateService;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public Map<String, Object> getTemplate() {
        return templateService.getTemplate();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listEligibleEmployees() {
        return accessibleNursingEmployees().stream()
                .map(e -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", e.getId());
                    m.put("fullName", e.getFullName());
                    m.put("employeeCode", e.getEmployeeCode());
                    m.put("departmentId", e.getDepartment() != null ? e.getDepartment().getId() : null);
                    m.put("departmentName", e.getDepartment() != null ? e.getDepartment().getName() : null);
                    m.put("positionTitle", e.getPosition() != null ? e.getPosition().getTitle() : null);
                    return m;
                })
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listDepartments() {
        return accessibleNursingDepartments().stream()
                .map(d -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", d.getId());
                    m.put("code", d.getCode());
                    m.put("name", d.getName());
                    return m;
                })
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> list(
            LocalDate from,
            LocalDate to,
            Long departmentId,
            String procedureCode,
            String status) {
        UserAccount actor = ensureCanAccess();
        if (from == null) from = LocalDate.now().withDayOfMonth(1);
        if (to == null) to = LocalDate.now();
        if (from.isAfter(to)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Khoảng ngày không hợp lệ");
        }

        List<Department> depts = accessibleNursingDepartments();
        Set<Long> deptIds = depts.stream().map(Department::getId).collect(Collectors.toSet());
        if (deptIds.isEmpty()) return List.of();

        if (departmentId != null && !deptIds.contains(departmentId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem khoa này");
        }

        QtktEvaluationStatus st = null;
        if (status != null && !status.isBlank()) {
            try {
                st = QtktEvaluationStatus.valueOf(status.trim().toUpperCase(Locale.ROOT));
            } catch (Exception e) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Trạng thái không hợp lệ");
            }
        }

        // Trưởng khoa chỉ thấy phiếu khoa mình; Trưởng phòng ĐD mặc định thấy đã gửi (+ nháp nếu lọc)
        if (!isNursingOfficeOrAdmin(actor) && st == null) {
            // show all statuses for own dept
        }

        return evaluationRepository.search(deptIds, from, to, st, blankToNull(procedureCode), departmentId)
                .stream()
                .map(this::toMap)
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> summary(String yearMonth) {
        ensureCanAccess();
        YearMonth ym = yearMonth != null && !yearMonth.isBlank()
                ? YearMonth.parse(yearMonth)
                : YearMonth.now();
        LocalDate from = ym.atDay(1);
        LocalDate to = ym.equals(YearMonth.now()) ? LocalDate.now() : ym.atEndOfMonth();

        List<Map<String, Object>> rows = list(from, to, null, null, "SUBMITTED");
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("yearMonth", ym.toString());
        out.put("from", from.toString());
        out.put("to", to.toString());
        out.put("totalSubmitted", rows.size());

        Map<String, List<Map<String, Object>>> byProc = rows.stream()
                .collect(Collectors.groupingBy(r -> String.valueOf(r.get("procedureCode")), LinkedHashMap::new, Collectors.toList()));
        List<Map<String, Object>> procedureStats = new ArrayList<>();
        for (Map<String, Object> proc : templateService.procedures()) {
            String code = String.valueOf(proc.get("code"));
            List<Map<String, Object>> items = byProc.getOrDefault(code, List.of());
            double avg = items.stream()
                    .mapToDouble(r -> ((Number) r.get("totalScore")).doubleValue())
                    .average()
                    .orElse(0);
            Map<String, Object> s = new LinkedHashMap<>();
            s.put("procedureCode", code);
            s.put("procedureName", proc.get("name"));
            s.put("count", items.size());
            s.put("avgScore", round2(avg));
            s.put("maxScore", proc.get("maxTotal"));
            procedureStats.add(s);
        }
        out.put("byProcedure", procedureStats);

        Map<Long, List<Map<String, Object>>> byDept = rows.stream()
                .collect(Collectors.groupingBy(r -> ((Number) r.get("departmentId")).longValue(), LinkedHashMap::new, Collectors.toList()));
        List<Map<String, Object>> deptStats = new ArrayList<>();
        for (Department d : accessibleNursingDepartments()) {
            List<Map<String, Object>> items = byDept.getOrDefault(d.getId(), List.of());
            double avg = items.stream()
                    .mapToDouble(r -> ((Number) r.get("totalScore")).doubleValue())
                    .average()
                    .orElse(0);
            Map<String, Object> s = new LinkedHashMap<>();
            s.put("departmentId", d.getId());
            s.put("departmentName", d.getName());
            s.put("count", items.size());
            s.put("avgScore", round2(avg));
            deptStats.add(s);
        }
        out.put("byDepartment", deptStats);

        Map<Long, List<Map<String, Object>>> byEmployee = rows.stream()
                .collect(Collectors.groupingBy(r -> ((Number) r.get("employeeId")).longValue(), LinkedHashMap::new, Collectors.toList()));
        List<Map<String, Object>> employeeStats = new ArrayList<>();
        for (Map.Entry<Long, List<Map<String, Object>>> e : byEmployee.entrySet()) {
            List<Map<String, Object>> items = e.getValue();
            if (items.isEmpty()) continue;
            Map<String, Object> first = items.get(0);
            double avg = items.stream()
                    .mapToDouble(r -> ((Number) r.get("totalScore")).doubleValue())
                    .average()
                    .orElse(0);
            Map<String, Object> s = new LinkedHashMap<>();
            s.put("employeeId", e.getKey());
            s.put("employeeName", first.get("employeeName"));
            s.put("employeeCode", first.get("employeeCode"));
            s.put("departmentId", first.get("departmentId"));
            s.put("departmentName", first.get("departmentName"));
            s.put("formCount", items.size());
            s.put("avgScore", round2(avg));
            s.put("maxScore", first.get("maxScore"));
            employeeStats.add(s);
        }
        employeeStats.sort(Comparator.comparing(
                (Map<String, Object> m) -> String.valueOf(m.get("employeeName")),
                String.CASE_INSENSITIVE_ORDER));
        out.put("byEmployee", employeeStats);
        return out;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getById(Long id) {
        QtktEvaluation e = evaluationRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá QTKT"));
        ensureDepartmentAllowed(e.getDepartment().getId());
        return toMap(e);
    }

    @Transactional
    public Map<String, Object> upsert(Long id, QtktEvaluationUpsertRequest req) {
        UserAccount actor = ensureCanAccess();
        if (!canCreate(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ Trưởng khoa / Trưởng phòng ĐD / ADMIN được nhập đánh giá QTKT");
        }

        Employee employee = employeeRepository.findById(req.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (!NursingBlockClassifier.matches(employee)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Nhân viên không thuộc khối Điều dưỡng được đánh giá QTKT");
        }
        if (employee.getDepartment() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Nhân viên chưa gán khoa/phòng");
        }
        ensureDepartmentAllowed(employee.getDepartment().getId());
        if (employee.getStatus() != EmployeeStatus.ACTIVE) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ đánh giá nhân viên đang làm việc");
        }

        Map<String, Object> procedure = templateService.requireProcedure(req.getProcedureCode());
        String departmentName = employee.getDepartment().getName();
        if (!templateService.isDepartmentAllowedForProcedure(req.getProcedureCode(), departmentName)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Quy trình này chỉ áp dụng cho các khoa lâm sàng được quy định (Nội–Nhi, Liên chuyên khoa, Ngoại, Sản, Hồi sức cấp cứu, Y học cổ truyền)");
        }
        String[] checkCtx = templateService.resolveCheckContext(req.getProcedureCode(), req.getCheckContextCode());
        String patientCode = templateService.resolvePatientCode(req.getProcedureCode(), req.getPatientCode());
        Map<String, Double> maxByStep = templateService.stepMaxPoints(req.getProcedureCode());
        Map<String, Double> normalized = normalizeScores(req.getScores(), maxByStep);
        BigDecimal total = BigDecimal.valueOf(
                        normalized.values().stream().mapToDouble(Double::doubleValue).sum())
                .setScale(2, RoundingMode.HALF_UP);
        BigDecimal maxScore = BigDecimal.valueOf(((Number) procedure.get("maxTotal")).doubleValue())
                .setScale(2, RoundingMode.HALF_UP);

        QtktEvaluation entity;
        if (id != null) {
            entity = evaluationRepository.findById(id)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá QTKT"));
            ensureDepartmentAllowed(entity.getDepartment().getId());
            if (entity.getStatus() == QtktEvaluationStatus.CANCELLED) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Phiếu đã hủy, không thể sửa");
            }
            if (!canEditEntity(actor, entity)) {
                throw new ApiException(HttpStatus.FORBIDDEN,
                        "Phiếu đã gửi — chỉ được xem. Thu hồi trong vòng 1 ngày (hoặc nhờ Trưởng phòng ĐD / ADMIN) để sửa.");
            }
            if (!entity.getEmployee().getId().equals(req.getEmployeeId())
                    || !entity.getProcedureCode().equals(req.getProcedureCode())
                    || !entity.getEvalDate().equals(req.getEvalDate())
                    || !Objects.equals(entity.getCheckContextCode(), checkCtx[0])
                    || !Objects.equals(blankToEmpty(entity.getPatientCode()), patientCode)) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Không được đổi nhân viên / quy trình / ngày / lựa chọn kiểm tra / mã bệnh nhân");
            }
        } else {
            evaluationRepository.findByEmployee_IdAndProcedureCodeAndEvalDateAndCheckContextCodeAndPatientCode(
                            req.getEmployeeId(), req.getProcedureCode(), req.getEvalDate(), checkCtx[0], patientCode)
                    .ifPresent(existing -> {
                        String ctxHint = checkCtx[1] != null ? " (" + checkCtx[1] + ")" : "";
                        String patientHint = !patientCode.isBlank() ? " · Mã BN " + patientCode : "";
                        throw new ApiException(HttpStatus.CONFLICT,
                                "Đã có phiếu đánh giá quy trình này cho nhân viên trong ngày "
                                        + req.getEvalDate() + ctxHint + patientHint + ". Vui lòng mở phiếu để chỉnh sửa.");
                    });
            entity = QtktEvaluation.builder()
                    .employee(employee)
                    .department(employee.getDepartment())
                    .procedureCode(req.getProcedureCode())
                    .procedureName(String.valueOf(procedure.get("name")))
                    .checkContextCode(checkCtx[0])
                    .checkContextLabel(checkCtx[1])
                    .patientCode(patientCode)
                    .evalDate(req.getEvalDate())
                    .createdBy(actor)
                    .status(QtktEvaluationStatus.DRAFT)
                    .build();
        }

        try {
            entity.setScoresJson(objectMapper.writeValueAsString(normalized));
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không lưu được bảng điểm");
        }
        entity.setTotalScore(total);
        entity.setMaxScore(maxScore);
        entity.setNote(req.getNote());
        entity.setUpdatedBy(actor);
        entity.setProcedureName(String.valueOf(procedure.get("name")));
        entity.setCheckContextCode(checkCtx[0]);
        entity.setCheckContextLabel(checkCtx[1]);
        entity.setPatientCode(patientCode);

        if (req.isSubmit()) {
            entity.setStatus(QtktEvaluationStatus.SUBMITTED);
            if (entity.getSubmittedAt() == null) {
                entity.setSubmittedAt(Instant.now());
            }
        } else if (entity.getStatus() != QtktEvaluationStatus.SUBMITTED) {
            entity.setStatus(QtktEvaluationStatus.DRAFT);
        }

        entity = evaluationRepository.save(entity);
        return toMap(entity);
    }

    @Transactional
    public Map<String, Object> submit(Long id) {
        UserAccount actor = ensureCanAccess();
        if (!canCreate(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền gửi phiếu");
        }
        QtktEvaluation entity = evaluationRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá QTKT"));
        ensureDepartmentAllowed(entity.getDepartment().getId());
        if (entity.getStatus() == QtktEvaluationStatus.CANCELLED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phiếu đã hủy");
        }
        if (entity.getStatus() == QtktEvaluationStatus.SUBMITTED && !isNursingOfficeOrAdmin(actor)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phiếu đã gửi rồi");
        }
        if (!canEditEntity(actor, entity) && entity.getStatus() != QtktEvaluationStatus.DRAFT) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền gửi phiếu này");
        }
        entity.setStatus(QtktEvaluationStatus.SUBMITTED);
        if (entity.getSubmittedAt() == null) {
            entity.setSubmittedAt(Instant.now());
        }
        entity.setUpdatedBy(actor);
        return toMap(evaluationRepository.save(entity));
    }

    /**
     * Thu hồi phiếu đã gửi → về nháp để chỉnh lại.
     * Trưởng khoa: trong vòng 24 giờ kể từ lúc gửi.
     * Trưởng phòng ĐD / ADMIN: mọi lúc.
     */
    @Transactional
    public Map<String, Object> recall(Long id) {
        UserAccount actor = ensureCanAccess();
        QtktEvaluation entity = evaluationRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá QTKT"));
        ensureDepartmentAllowed(entity.getDepartment().getId());
        if (entity.getStatus() != QtktEvaluationStatus.SUBMITTED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ thu hồi được phiếu đã gửi");
        }
        if (!canRecallEntity(actor, entity)) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Đã quá 1 ngày kể từ lúc gửi — chỉ Trưởng phòng Điều dưỡng hoặc ADMIN được thu hồi");
        }
        entity.setStatus(QtktEvaluationStatus.DRAFT);
        entity.setSubmittedAt(null);
        entity.setUpdatedBy(actor);
        return toMap(evaluationRepository.save(entity));
    }

    /** @deprecated Dùng {@link #recall(Long)} — giữ endpoint cancel tương thích. */
    @Transactional
    public Map<String, Object> cancel(Long id) {
        return recall(id);
    }

    private Map<String, Double> normalizeScores(Map<String, Double> input, Map<String, Double> maxByStep) {
        Map<String, Double> out = new LinkedHashMap<>();
        for (Map.Entry<String, Double> e : maxByStep.entrySet()) {
            double max = e.getValue();
            Double raw = input != null ? input.get(e.getKey()) : null;
            double v = raw == null || !Double.isFinite(raw) ? 0 : raw;
            if (v < 0) v = 0;
            if (v > max) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Điểm bước " + e.getKey() + " không được vượt " + max);
            }
            out.put(e.getKey(), BigDecimal.valueOf(v).setScale(2, RoundingMode.HALF_UP).doubleValue());
        }
        if (input != null) {
            for (String k : input.keySet()) {
                if (!maxByStep.containsKey(k)) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "Bước điểm không hợp lệ: " + k);
                }
            }
        }
        return out;
    }

    private UserAccount ensureCanAccess() {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && actor.getRole() != UserRole.HEAD_NURSING
                && actor.getRole() != UserRole.HEAD_DEPARTMENT) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền truy cập đánh giá QTKT");
        }
        return actor;
    }

    private boolean isNursingOfficeOrAdmin(UserAccount actor) {
        return actor.getRole() == UserRole.ADMIN || actor.getRole() == UserRole.HEAD_NURSING;
    }

    private boolean canCreate(UserAccount actor) {
        return isNursingOfficeOrAdmin(actor) || actor.getRole() == UserRole.HEAD_DEPARTMENT;
    }

    private boolean canEditEntity(UserAccount actor, QtktEvaluation entity) {
        if (entity.getStatus() == QtktEvaluationStatus.CANCELLED) {
            return false;
        }
        if (isNursingOfficeOrAdmin(actor)) {
            return true;
        }
        return actor.getRole() == UserRole.HEAD_DEPARTMENT
                && entity.getStatus() == QtktEvaluationStatus.DRAFT;
    }

    private boolean canRecallEntity(UserAccount actor, QtktEvaluation entity) {
        if (entity.getStatus() != QtktEvaluationStatus.SUBMITTED) {
            return false;
        }
        if (isNursingOfficeOrAdmin(actor)) {
            return true;
        }
        return actor.getRole() == UserRole.HEAD_DEPARTMENT && withinRecallWindow(entity.getSubmittedAt());
    }

    /** Trong vòng 24 giờ kể từ lúc gửi. */
    private static boolean withinRecallWindow(Instant submittedAt) {
        if (submittedAt == null) {
            return true;
        }
        return Instant.now().isBefore(submittedAt.plus(1, ChronoUnit.DAYS));
    }

    private List<Department> accessibleNursingDepartments() {
        UserAccount actor = ensureCanAccess();
        List<Department> nursingDepts = actor.getRole() == UserRole.HEAD_NURSING
                ? departmentService.listNursingHeadScopeDepartments()
                : departmentService.listNursingBlockDepartments();
        if (isNursingOfficeOrAdmin(actor)) {
            return nursingDepts;
        }
        Long scoped = employeeService.resolveHeadDepartmentScope(actor);
        if (scoped == null) return List.of();
        return nursingDepts.stream().filter(d -> Objects.equals(d.getId(), scoped)).toList();
    }

    private List<Employee> accessibleNursingEmployees() {
        List<Department> depts = accessibleNursingDepartments();
        List<Employee> all = new ArrayList<>();
        for (Department d : depts) {
            all.addAll(employeeRepository.findByDepartment_IdAndStatus(
                    d.getId(), EmployeeStatus.ACTIVE, Sort.by("fullName")));
        }
        return all.stream().filter(NursingBlockClassifier::matches).toList();
    }

    private void ensureDepartmentAllowed(Long departmentId) {
        boolean ok = accessibleNursingDepartments().stream().anyMatch(d -> d.getId().equals(departmentId));
        if (!ok) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền thao tác khoa/phòng này");
        }
    }

    private Map<String, Object> toMap(QtktEvaluation e) {
        UserAccount actor = employeeService.currentUser();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", e.getId());
        m.put("employeeId", e.getEmployee().getId());
        m.put("employeeName", e.getEmployee().getFullName());
        m.put("employeeCode", e.getEmployee().getEmployeeCode());
        m.put("departmentId", e.getDepartment().getId());
        m.put("departmentName", e.getDepartment().getName());
        m.put("procedureCode", e.getProcedureCode());
        m.put("procedureName", e.getProcedureName());
        m.put("checkContextCode", e.getCheckContextCode());
        m.put("checkContextLabel", e.getCheckContextLabel());
        m.put("patientCode", e.getPatientCode() != null && !e.getPatientCode().isBlank() ? e.getPatientCode() : null);
        m.put("evalDate", e.getEvalDate().toString());
        m.put("totalScore", e.getTotalScore());
        m.put("maxScore", e.getMaxScore());
        m.put("note", e.getNote());
        m.put("status", e.getStatus().name());
        m.put("submittedAt", e.getSubmittedAt() != null ? e.getSubmittedAt().toString() : null);
        m.put("canEdit", canEditEntity(actor, e));
        m.put("canRecall", canRecallEntity(actor, e));
        m.put("createdByUsername", e.getCreatedBy() != null ? e.getCreatedBy().getUsername() : null);
        m.put("createdByName", accountDisplayName(e.getCreatedBy()));
        m.put("updatedByUsername", e.getUpdatedBy() != null ? e.getUpdatedBy().getUsername() : null);
        m.put("updatedByName", accountDisplayName(e.getUpdatedBy()));
        m.put("createdAt", e.getCreatedAt() != null ? e.getCreatedAt().toString() : null);
        m.put("updatedAt", e.getUpdatedAt() != null ? e.getUpdatedAt().toString() : null);
        try {
            m.put("scores", objectMapper.readValue(e.getScoresJson(), new TypeReference<Map<String, Double>>() {}));
        } catch (Exception ex) {
            m.put("scores", Map.of());
        }
        return m;
    }

    private static String accountDisplayName(UserAccount u) {
        if (u == null) return null;
        if (u.getEmployee() != null && u.getEmployee().getFullName() != null && !u.getEmployee().getFullName().isBlank()) {
            return u.getEmployee().getFullName().trim();
        }
        if (u.getDisplayName() != null && !u.getDisplayName().isBlank()) {
            return u.getDisplayName().trim();
        }
        return u.getUsername();
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static String blankToEmpty(String s) {
        return s == null ? "" : s.trim();
    }

    private static double round2(double v) {
        return BigDecimal.valueOf(v).setScale(2, RoundingMode.HALF_UP).doubleValue();
    }
}
