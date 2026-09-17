package com.minhan.hrm.service;

import com.minhan.hrm.dto.nursingdaily.NursingDailyReportUpsertRequest;
import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.NursingDailyReport;
import com.minhan.hrm.entity.NursingDailyReportStatus;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.NursingDailyReportRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class NursingDailyReportService {

    private final NursingDailyReportRepository reportRepository;
    private final DepartmentRepository departmentRepository;
    private final DepartmentService departmentService;
    private final EmployeeService employeeService;

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
    public List<Map<String, Object>> listForDate(LocalDate date, Long departmentId) {
        UserAccount actor = ensureCanAccess();
        if (date == null) {
            date = LocalDate.now();
        }
        List<Department> depts = accessibleNursingDepartments();
        if (departmentId != null) {
            depts = depts.stream().filter(d -> d.getId().equals(departmentId)).toList();
        }
        Set<Long> deptIds = depts.stream().map(Department::getId).collect(Collectors.toSet());
        Map<Long, NursingDailyReport> byDept = deptIds.isEmpty()
                ? Map.of()
                : reportRepository.findByReportDateAndDepartment_IdInOrderByDepartment_NameAsc(date, deptIds)
                        .stream()
                        .collect(Collectors.toMap(r -> r.getDepartment().getId(), r -> r, (a, b) -> a));

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Department d : depts) {
            rows.add(toDayRow(actor, d, date, byDept.get(d.getId())));
        }
        return rows;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listForMonth(java.time.YearMonth yearMonth, Long departmentId) {
        UserAccount actor = ensureCanAccess();
        java.time.YearMonth ym = yearMonth != null ? yearMonth : java.time.YearMonth.now();
        LocalDate today = LocalDate.now();
        LocalDate from = ym.atDay(1);
        LocalDate monthEnd = ym.atEndOfMonth();
        if (from.isAfter(today)) {
            return List.of();
        }
        LocalDate to = monthEnd.isAfter(today) ? today : monthEnd;

        List<Department> depts = accessibleNursingDepartments();
        if (departmentId != null) {
            depts = depts.stream().filter(d -> d.getId().equals(departmentId)).toList();
        }
        if (depts.isEmpty()) {
            return List.of();
        }

        Set<Long> deptIds = depts.stream().map(Department::getId).collect(Collectors.toSet());
        Map<String, NursingDailyReport> byKey = reportRepository
                .findByDepartment_IdInAndReportDateBetweenOrderByReportDateAscDepartment_NameAsc(deptIds, from, to)
                .stream()
                .collect(Collectors.toMap(
                        r -> r.getDepartment().getId() + "|" + r.getReportDate(),
                        r -> r,
                        (a, b) -> a));

        List<Map<String, Object>> rows = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            for (Department dept : depts) {
                String key = dept.getId() + "|" + d;
                rows.add(toDayRow(actor, dept, d, byKey.get(key)));
            }
        }
        return rows;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getById(Long id) {
        NursingDailyReport report = reportRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy báo cáo"));
        ensureDepartmentAllowed(report.getDepartment().getId());
        return toMap(report);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getByDepartmentAndDate(Long departmentId, LocalDate date) {
        ensureDepartmentAllowed(departmentId);
        return reportRepository.findByDepartment_IdAndReportDate(departmentId, date)
                .map(this::toMap)
                .orElse(null);
    }

    @Transactional
    public Map<String, Object> create(NursingDailyReportUpsertRequest req) {
        UserAccount actor = ensureCanAccess();
        ensureDepartmentAllowed(req.getDepartmentId());
        if (reportRepository.existsByDepartment_IdAndReportDate(req.getDepartmentId(), req.getReportDate())) {
            throw new ApiException(HttpStatus.CONFLICT,
                    "Khoa này đã có báo cáo cho ngày " + req.getReportDate() + ". Vui lòng mở phiếu để chỉnh sửa.");
        }
        Department dept = departmentRepository.findById(req.getDepartmentId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy khoa/phòng"));
        NursingDailyReport report = NursingDailyReport.builder()
                .department(dept)
                .reportDate(req.getReportDate())
                .createdBy(actor)
                .status(NursingDailyReportStatus.DRAFT)
                .build();
        applyFields(report, req);
        applySubmitState(report, req.isSubmit());
        report = reportRepository.save(report);
        return toMap(report);
    }

    @Transactional
    public Map<String, Object> update(Long id, NursingDailyReportUpsertRequest req) {
        UserAccount actor = ensureCanAccess();
        NursingDailyReport report = reportRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy báo cáo"));
        ensureDepartmentAllowed(report.getDepartment().getId());
        if (!report.getDepartment().getId().equals(req.getDepartmentId())
                || !report.getReportDate().equals(req.getReportDate())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không được đổi khoa hoặc ngày báo cáo");
        }
        if (!canEditEntity(actor, report)) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Báo cáo đã gửi — chỉ được xem. Thu hồi trong vòng 1 ngày (hoặc nhờ Trưởng phòng ĐD / ADMIN) để sửa.");
        }
        applyFields(report, req);
        applySubmitState(report, req.isSubmit());
        report.setUpdatedBy(actor);
        report = reportRepository.save(report);
        return toMap(report);
    }

    /**
     * Thu hồi báo cáo đã gửi → nháp để chỉnh lại.
     * Trưởng khoa: trong 24 giờ; Trưởng phòng ĐD / ADMIN: mọi lúc.
     */
    @Transactional
    public Map<String, Object> recall(Long id) {
        UserAccount actor = ensureCanAccess();
        NursingDailyReport report = reportRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy báo cáo"));
        ensureDepartmentAllowed(report.getDepartment().getId());
        if (report.getStatus() != NursingDailyReportStatus.SUBMITTED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ thu hồi được báo cáo đã gửi");
        }
        if (!canRecallEntity(actor, report)) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Đã quá 1 ngày kể từ lúc gửi — chỉ Trưởng phòng Điều dưỡng hoặc ADMIN được thu hồi");
        }
        report.setStatus(NursingDailyReportStatus.DRAFT);
        report.setSubmittedAt(null);
        report.setUpdatedBy(actor);
        return toMap(reportRepository.save(report));
    }

    @Transactional
    public void delete(Long id) {
        UserAccount actor = ensureCanAccess();
        if (actor.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ ADMIN được xoá báo cáo");
        }
        NursingDailyReport report = reportRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy báo cáo"));
        reportRepository.delete(report);
    }

    private void applySubmitState(NursingDailyReport report, boolean submit) {
        if (submit) {
            report.setStatus(NursingDailyReportStatus.SUBMITTED);
            if (report.getSubmittedAt() == null) {
                report.setSubmittedAt(Instant.now());
            }
        } else {
            report.setStatus(NursingDailyReportStatus.DRAFT);
            report.setSubmittedAt(null);
        }
    }

    private void applyFields(NursingDailyReport report, NursingDailyReportUpsertRequest req) {
        report.setTotalStaff(req.getTotalStaff());
        report.setWorkingStaff(req.getWorkingStaff());
        report.setPlannedLeave(req.getPlannedLeave());
        report.setUnplannedLeave(req.getUnplannedLeave());
        report.setMaternityLeave(req.getMaternityLeave());
        report.setLongLeave(req.getLongLeave());
        report.setDutyAfternoonOff(req.getDutyAfternoonOff());
        report.setExternalMission(req.getExternalMission());
        applyInpatients(report, req);
        report.setOutpatients(req.getOutpatients());
        report.setParaclinical(req.getParaclinical());
        report.setSurgery(req.getSurgery());
        report.setDischargedYesterday(req.getDischargedYesterday());
        report.setActualBeds(req.getActualBeds());
        report.setPlannedBeds(req.getPlannedBeds());
        report.setInpatientTreatmentDays(req.getInpatientTreatmentDays());
        report.setFalls(req.getFalls());
        report.setNewPressureUlcers(req.getNewPressureUlcers());
        report.setIdMixups(req.getIdMixups());
        report.setMedicationErrors(req.getMedicationErrors());
    }

    /**
     * Ưu tiên 3 cấp chăm sóc nếu client gửi; tổng {@code inpatients} = cấp 1+2+3.
     * Client cũ chỉ gửi tổng → giữ tổng, cấp để 0.
     */
    private static void applyInpatients(NursingDailyReport report, NursingDailyReportUpsertRequest req) {
        boolean levelsSent = req.getInpatientsCareLevel1() != null
                || req.getInpatientsCareLevel2() != null
                || req.getInpatientsCareLevel3() != null;
        if (levelsSent) {
            int l1 = nz(req.getInpatientsCareLevel1());
            int l2 = nz(req.getInpatientsCareLevel2());
            int l3 = nz(req.getInpatientsCareLevel3());
            report.setInpatientsCareLevel1(l1);
            report.setInpatientsCareLevel2(l2);
            report.setInpatientsCareLevel3(l3);
            report.setInpatients(l1 + l2 + l3);
            return;
        }
        int total = nz(req.getInpatients());
        report.setInpatients(total);
        report.setInpatientsCareLevel1(0);
        report.setInpatientsCareLevel2(0);
        report.setInpatientsCareLevel3(0);
    }

    private static int nz(Integer v) {
        return v == null || v < 0 ? 0 : v;
    }

    private Map<String, Object> toDayRow(UserAccount actor, Department d, LocalDate date, NursingDailyReport report) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("departmentId", d.getId());
        row.put("departmentCode", d.getCode());
        row.put("departmentName", d.getName());
        row.put("reportDate", date.toString());
        boolean submitted = report != null && report.getStatus() == NursingDailyReportStatus.SUBMITTED;
        boolean hasDraft = report != null && report.getStatus() == NursingDailyReportStatus.DRAFT;
        row.put("submitted", submitted);
        row.put("hasDraft", hasDraft);
        row.put("canEdit", report == null ? canEditDepartment(actor, d.getId()) : canEditEntity(actor, report));
        row.put("canRecall", report != null && canRecallEntity(actor, report));
        row.put("report", report != null ? toMap(report, actor) : null);
        return row;
    }

    private UserAccount ensureCanAccess() {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && actor.getRole() != UserRole.HEAD_NURSING
                && actor.getRole() != UserRole.HEAD_DEPARTMENT) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền truy cập báo cáo điều dưỡng hằng ngày");
        }
        return actor;
    }

    private boolean isNursingOfficeOrAdmin(UserAccount actor) {
        return actor.getRole() == UserRole.ADMIN || actor.getRole() == UserRole.HEAD_NURSING;
    }

    private List<Department> accessibleNursingDepartments() {
        UserAccount actor = ensureCanAccess();
        List<Department> nursingDepts = actor.getRole() == UserRole.HEAD_NURSING
                ? departmentService.listNursingHeadScopeDepartments()
                : departmentService.listNursingBlockDepartments();
        if (isNursingOfficeOrAdmin(actor)) {
            return nursingDepts;
        }
        Long scopedDept = employeeService.resolveHeadDepartmentScope(actor);
        if (scopedDept == null) {
            return List.of();
        }
        return nursingDepts.stream()
                .filter(d -> Objects.equals(d.getId(), scopedDept))
                .toList();
    }

    private boolean canEditDepartment(UserAccount actor, Long departmentId) {
        if (isNursingOfficeOrAdmin(actor)) {
            return true;
        }
        Long scopedDept = employeeService.resolveHeadDepartmentScope(actor);
        return scopedDept != null && scopedDept.equals(departmentId);
    }

    private boolean canEditEntity(UserAccount actor, NursingDailyReport report) {
        if (!canEditDepartment(actor, report.getDepartment().getId())) {
            return false;
        }
        if (isNursingOfficeOrAdmin(actor)) {
            return true;
        }
        return report.getStatus() == NursingDailyReportStatus.DRAFT;
    }

    private boolean canRecallEntity(UserAccount actor, NursingDailyReport report) {
        if (report.getStatus() != NursingDailyReportStatus.SUBMITTED) {
            return false;
        }
        if (!canEditDepartment(actor, report.getDepartment().getId())) {
            return false;
        }
        if (isNursingOfficeOrAdmin(actor)) {
            return true;
        }
        return withinRecallWindow(report.getSubmittedAt());
    }

    private static boolean withinRecallWindow(Instant submittedAt) {
        if (submittedAt == null) {
            return true;
        }
        return Instant.now().isBefore(submittedAt.plus(1, ChronoUnit.DAYS));
    }

    private void ensureDepartmentAllowed(Long departmentId) {
        UserAccount actor = ensureCanAccess();
        boolean inNursingBlock = departmentService.listNursingBlockDepartments().stream()
                .anyMatch(d -> d.getId().equals(departmentId));
        if (!inNursingBlock) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Khoa/phòng không thuộc khối Điều dưỡng được phép lập báo cáo");
        }
        if (!canEditDepartment(actor, departmentId)) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Chỉ được nhập/sửa báo cáo của khoa mình phụ trách");
        }
    }

    private Map<String, Object> toMap(NursingDailyReport r) {
        return toMap(r, employeeService.currentUser());
    }

    private Map<String, Object> toMap(NursingDailyReport r, UserAccount actor) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("departmentId", r.getDepartment().getId());
        m.put("departmentCode", r.getDepartment().getCode());
        m.put("departmentName", r.getDepartment().getName());
        m.put("reportDate", r.getReportDate().toString());
        m.put("status", r.getStatus() != null ? r.getStatus().name() : NursingDailyReportStatus.SUBMITTED.name());
        m.put("submittedAt", r.getSubmittedAt() != null ? r.getSubmittedAt().toString() : null);
        m.put("canEdit", canEditEntity(actor, r));
        m.put("canRecall", canRecallEntity(actor, r));
        m.put("totalStaff", r.getTotalStaff());
        m.put("workingStaff", r.getWorkingStaff());
        m.put("plannedLeave", r.getPlannedLeave());
        m.put("unplannedLeave", r.getUnplannedLeave());
        m.put("maternityLeave", r.getMaternityLeave());
        m.put("longLeave", r.getLongLeave());
        m.put("dutyAfternoonOff", r.getDutyAfternoonOff());
        m.put("externalMission", r.getExternalMission());
        m.put("inpatients", r.getInpatients());
        m.put("inpatientsCareLevel1", r.getInpatientsCareLevel1());
        m.put("inpatientsCareLevel2", r.getInpatientsCareLevel2());
        m.put("inpatientsCareLevel3", r.getInpatientsCareLevel3());
        m.put("outpatients", r.getOutpatients());
        m.put("paraclinical", r.getParaclinical());
        m.put("surgery", r.getSurgery());
        m.put("dischargedYesterday", r.getDischargedYesterday());
        m.put("actualBeds", r.getActualBeds());
        m.put("plannedBeds", r.getPlannedBeds());
        m.put("inpatientTreatmentDays", r.getInpatientTreatmentDays());
        m.put("falls", r.getFalls());
        m.put("newPressureUlcers", r.getNewPressureUlcers());
        m.put("idMixups", r.getIdMixups());
        m.put("medicationErrors", r.getMedicationErrors());
        m.put("createdByUsername", r.getCreatedBy() != null ? r.getCreatedBy().getUsername() : null);
        m.put("updatedByUsername", r.getUpdatedBy() != null ? r.getUpdatedBy().getUsername() : null);
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        m.put("updatedAt", r.getUpdatedAt() != null ? r.getUpdatedAt().toString() : null);
        return m;
    }
}
