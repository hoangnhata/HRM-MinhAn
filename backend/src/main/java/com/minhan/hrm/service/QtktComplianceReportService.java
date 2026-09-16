package com.minhan.hrm.service;

import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.QtktEvaluationRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class QtktComplianceReportService {

    public static final String HAND_WASH = "HAND_WASH";
    public static final String GDSK_COUNSELING = "GDSK_COUNSELING";
    public static final List<String> TECHNICAL_PROCEDURES = List.of("IV_INJECTION", "IV_INFUSION", "IV_CATHETER");
    private static final BigDecimal HAND_WASH_PASS_SCORE = BigDecimal.TEN;
    private static final BigDecimal TECHNICAL_PASS_MIN = BigDecimal.valueOf(7);
    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final QtktEvaluationRepository evaluationRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeService employeeService;
    private final DepartmentService departmentService;
    private final QtktTemplateService templateService;
    private final ObjectMapper objectMapper;

    public enum ReportKind {
        HAND_HYGIENE,
        TECHNICAL,
        GDSK
    }

    @Transactional(readOnly = true)
    public Map<String, Object> handHygieneReport(
            LocalDate from,
            LocalDate to,
            Long departmentId,
            Long employeeId,
            String search,
            String resultFilter,
            String sortDir,
            int page,
            int size) {
        return buildReport(ReportKind.HAND_HYGIENE, from, to, departmentId, employeeId, null,
                search, resultFilter, sortDir, page, size);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> technicalReport(
            LocalDate from,
            LocalDate to,
            Long departmentId,
            Long employeeId,
            String procedureCode,
            String search,
            String resultFilter,
            String sortDir,
            int page,
            int size) {
        return buildReport(ReportKind.TECHNICAL, from, to, departmentId, employeeId, procedureCode,
                search, resultFilter, sortDir, page, size);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> gdskReport(
            LocalDate from,
            LocalDate to,
            Long departmentId,
            Long employeeId,
            String search,
            String resultFilter,
            String sortDir,
            int page,
            int size) {
        return buildReport(ReportKind.GDSK, from, to, departmentId, employeeId, null,
                search, resultFilter, sortDir, page, size);
    }

    private Map<String, Object> buildReport(
            ReportKind kind,
            LocalDate from,
            LocalDate to,
            Long departmentId,
            Long employeeId,
            String procedureCode,
            String search,
            String resultFilter,
            String sortDir,
            int page,
            int size) {
        UserAccount actor = ensureCanAccess();
        DateRange range = resolveRange(from, to);
        validateDepartmentAccess(departmentId);

        List<String> procedureCodes = resolveProcedureCodes(kind, procedureCode);
        Set<Long> deptIds = departmentsForReport(kind).stream().map(Department::getId).collect(Collectors.toSet());
        if (deptIds.isEmpty()) {
            return emptyReport(kind, range, departmentId, employeeId, procedureCode);
        }

        List<QtktEvaluation> rows = evaluationRepository.findSubmittedForCompliance(
                deptIds, range.from(), range.to(), procedureCodes, departmentId, employeeId);

        List<Map<String, Object>> detailRows = rows.stream()
                .map(e -> toDetailRow(e, kind))
                .toList();

        detailRows = filterDetails(detailRows, search, resultFilter);
        detailRows = sortDetails(detailRows, sortDir);

        Map<String, Object> kpi = computeKpi(detailRows);
        List<Map<String, Object>> byDepartment = computeByDepartment(detailRows, kind);
        List<Map<String, Object>> trend = computeTrend(detailRows, range.from(), range.to());

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("reportKind", kind.name());
        out.put("reportTitle", reportTitle(kind));
        out.put("formulaNote", formulaNote(kind));
        out.put("from", range.from().toString());
        out.put("to", range.to().toString());
        out.put("yearMonth", YearMonth.from(range.from()).toString());
        out.put("departmentId", departmentId);
        out.put("departmentName", resolveDepartmentLabel(departmentId));
        out.put("employeeId", employeeId);
        out.put("employeeName", resolveEmployeeLabel(employeeId));
        out.put("procedureCode", blankToNull(procedureCode));
        out.put("kpi", kpi);
        out.put("byDepartment", byDepartment);
        out.put("trend", trend);
        out.put("trendGranularity", trendGranularity(range.from(), range.to()));

        if (kind == ReportKind.HAND_HYGIENE) {
            out.put("byCheckContext", computeByCheckContext(detailRows));
        } else if (kind == ReportKind.TECHNICAL) {
            out.put("byProcedure", computeByProcedure(detailRows, procedureCode));
            out.put("trendByProcedure", computeTrendByProcedure(detailRows, range.from(), range.to(), procedureCode));
        }

        out.put("details", paginate(detailRows, page, size));
        out.put("filters", Map.of(
                "search", search != null ? search : "",
                "resultFilter", normalizeResultFilter(resultFilter),
                "sortDir", normalizeSortDir(sortDir)
        ));
        out.put("actorRole", actor.getRole().name());
        return out;
    }

    private Map<String, Object> emptyReport(
            ReportKind kind, DateRange range, Long departmentId, Long employeeId, String procedureCode) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("reportKind", kind.name());
        out.put("reportTitle", reportTitle(kind));
        out.put("formulaNote", formulaNote(kind));
        out.put("from", range.from().toString());
        out.put("to", range.to().toString());
        out.put("yearMonth", YearMonth.from(range.from()).toString());
        out.put("departmentId", departmentId);
        out.put("departmentName", resolveDepartmentLabel(departmentId));
        out.put("employeeId", employeeId);
        out.put("employeeName", resolveEmployeeLabel(employeeId));
        out.put("procedureCode", blankToNull(procedureCode));
        out.put("kpi", computeKpi(List.of()));
        out.put("byDepartment", List.of());
        out.put("trend", List.of());
        out.put("trendGranularity", trendGranularity(range.from(), range.to()));
        if (kind == ReportKind.HAND_HYGIENE) {
            out.put("byCheckContext", orderedEmptyCheckContexts());
        } else if (kind == ReportKind.TECHNICAL) {
            out.put("byProcedure", computeByProcedure(List.of(), procedureCode));
            out.put("trendByProcedure", Map.of());
        }
        out.put("details", paginate(List.of(), 0, 20));
        return out;
    }

    private static String reportTitle(ReportKind kind) {
        return switch (kind) {
            case HAND_HYGIENE -> "Báo cáo tỷ lệ tuân thủ vệ sinh tay";
            case TECHNICAL -> "Báo cáo tỷ lệ tuân thủ quy trình kỹ thuật";
            case GDSK -> "Báo cáo tỷ lệ người bệnh được tư vấn, truyền thông GDSK hiệu quả ở các khoa lâm sàng";
        };
    }

    private static String formulaNote(ReportKind kind) {
        return switch (kind) {
            case HAND_HYGIENE -> "Tỷ lệ tuân thủ = (Số lần đạt 10/10 / Tổng số lần đánh giá) × 100%";
            case TECHNICAL -> "Tỷ lệ tuân thủ = (Số lần đạt ≥ 7/10 / Tổng số lần đánh giá) × 100%";
            case GDSK -> "Tỷ lệ tuân thủ = (Tổng số lần tư vấn đạt hiệu quả (đánh giá đạt theo bảng kiểm) / Tổng số NB được tư vấn trong kỳ báo cáo) × 100%";
        };
    }

    private List<Map<String, Object>> orderedEmptyCheckContexts() {
        Map<String, Object> opts = templateService.checkOptions(HAND_WASH);
        if (opts == null || opts.isEmpty()) return List.of();
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> options = (List<Map<String, Object>>) opts.get("options");
        if (options == null) return List.of();
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> o : options) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("checkContextCode", o.get("code"));
            row.put("checkContextLabel", o.get("label"));
            row.put("total", 0);
            row.put("passed", 0);
            row.put("failed", 0);
            row.put("complianceRate", null);
            row.put("hasData", false);
            out.add(row);
        }
        return out;
    }

    private List<Map<String, Object>> computeByCheckContext(List<Map<String, Object>> rows) {
        Map<String, List<Map<String, Object>>> grouped = rows.stream()
                .collect(Collectors.groupingBy(r -> String.valueOf(r.get("checkContextCode")), LinkedHashMap::new, Collectors.toList()));

        List<Map<String, Object>> templateOrder = orderedEmptyCheckContexts();
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> tpl : templateOrder) {
            String code = String.valueOf(tpl.get("checkContextCode"));
            List<Map<String, Object>> items = grouped.getOrDefault(code, List.of());
            String label = items.isEmpty() ? String.valueOf(tpl.get("checkContextLabel")) : String.valueOf(items.get(0).get("checkContextLabel"));
            Map<String, Object> row = bucketStats(code, label, items);
            row.put("checkContextCode", code);
            row.put("checkContextLabel", label);
            out.add(row);
        }
        for (Map.Entry<String, List<Map<String, Object>>> e : grouped.entrySet()) {
            if (templateOrder.stream().anyMatch(t -> e.getKey().equals(String.valueOf(t.get("checkContextCode"))))) continue;
            List<Map<String, Object>> items = e.getValue();
            String label = items.isEmpty() ? e.getKey() : String.valueOf(items.get(0).get("checkContextLabel"));
            Map<String, Object> row = bucketStats(e.getKey(), label, items);
            row.put("checkContextCode", e.getKey());
            row.put("checkContextLabel", label);
            out.add(row);
        }
        return out;
    }

    private Map<String, List<Map<String, Object>>> computeTrendByProcedure(
            List<Map<String, Object>> rows, LocalDate from, LocalDate to, String selectedProcedure) {
        Map<String, List<Map<String, Object>>> out = new LinkedHashMap<>();
        for (String code : TECHNICAL_PROCEDURES) {
            if (selectedProcedure != null && !selectedProcedure.isBlank() && !code.equals(selectedProcedure)) continue;
            List<Map<String, Object>> procRows = rows.stream()
                    .filter(r -> code.equals(String.valueOf(r.get("procedureCode"))))
                    .toList();
            out.put(code, computeTrend(procRows, from, to));
        }
        return out;
    }

    private List<Map<String, Object>> computeByProcedure(List<Map<String, Object>> rows, String selectedProcedure) {
        Map<String, List<Map<String, Object>>> grouped = rows.stream()
                .collect(Collectors.groupingBy(r -> String.valueOf(r.get("procedureCode")), LinkedHashMap::new, Collectors.toList()));

        List<Map<String, Object>> out = new ArrayList<>();
        for (String code : TECHNICAL_PROCEDURES) {
            if (selectedProcedure != null && !selectedProcedure.isBlank() && !code.equals(selectedProcedure)) continue;
            List<Map<String, Object>> items = grouped.getOrDefault(code, List.of());
            String name = items.isEmpty() ? procedureName(code) : String.valueOf(items.get(0).get("procedureName"));
            Map<String, Object> row = bucketStats(code, name, items);
            row.put("procedureCode", code);
            row.put("procedureName", name);
            out.add(row);
        }

        if (selectedProcedure == null || selectedProcedure.isBlank()) {
            Map<String, Object> total = bucketStats("TOTAL", "Tổng QTKT", rows);
            total.put("procedureCode", "TOTAL");
            total.put("procedureName", "Tổng QTKT");
            total.put("isTotal", true);
            out.add(total);
        }
        return out;
    }

    private List<Map<String, Object>> computeByDepartment(List<Map<String, Object>> rows, ReportKind kind) {
        Map<Long, List<Map<String, Object>>> grouped = rows.stream()
                .collect(Collectors.groupingBy(r -> ((Number) r.get("departmentId")).longValue(), LinkedHashMap::new, Collectors.toList()));

        List<Map<String, Object>> out = new ArrayList<>();
        for (Department d : departmentsForReport(kind)) {
            List<Map<String, Object>> items = grouped.getOrDefault(d.getId(), List.of());
            Map<String, Object> row = bucketStats(String.valueOf(d.getId()), d.getName(), items);
            row.put("departmentId", d.getId());
            row.put("departmentName", d.getName());
            if (kind == ReportKind.TECHNICAL) {
                row.put("byProcedure", computeByProcedure(items, null));
            }
            out.add(row);
        }
        return out.stream()
                .sorted(Comparator.comparingInt(r -> -((Number) r.get("total")).intValue()))
                .toList();
    }

    private Map<String, Object> bucketStats(String code, String label, List<Map<String, Object>> items) {
        int total = items.size();
        int passed = (int) items.stream().filter(r -> Boolean.TRUE.equals(r.get("passed"))).count();
        int failed = total - passed;
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("code", code);
        m.put("label", label);
        m.put("total", total);
        m.put("passed", passed);
        m.put("failed", failed);
        m.put("complianceRate", complianceRate(total, passed));
        m.put("hasData", total > 0);
        return m;
    }

    private List<Map<String, Object>> computeTrend(List<Map<String, Object>> rows, LocalDate from, LocalDate to) {
        String granularity = trendGranularity(from, to);
        Map<String, List<Map<String, Object>>> buckets = new LinkedHashMap<>();

        for (Map<String, Object> row : rows) {
            LocalDate d = LocalDate.parse(String.valueOf(row.get("evalDate")));
            String key = bucketKey(d, granularity);
            buckets.computeIfAbsent(key, k -> new ArrayList<>()).add(row);
        }

        List<String> orderedKeys = orderedBucketKeys(from, to, granularity);
        List<Map<String, Object>> out = new ArrayList<>();
        for (String key : orderedKeys) {
            List<Map<String, Object>> items = buckets.getOrDefault(key, List.of());
            int total = items.size();
            int passed = (int) items.stream().filter(r -> Boolean.TRUE.equals(r.get("passed"))).count();
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("bucketKey", key);
            m.put("label", bucketLabel(key, granularity));
            m.put("total", total);
            m.put("passed", passed);
            m.put("failed", total - passed);
            m.put("complianceRate", complianceRate(total, passed));
            m.put("hasData", total > 0);
            out.add(m);
        }
        return out;
    }

    private String trendGranularity(LocalDate from, LocalDate to) {
        long days = ChronoUnit.DAYS.between(from, to) + 1;
        if (days > 90) return "MONTH";
        if (days > 31) return "WEEK";
        return "DAY";
    }

    private String bucketKey(LocalDate date, String granularity) {
        return switch (granularity) {
            case "MONTH" -> YearMonth.from(date).toString();
            case "WEEK" -> date.with(java.time.DayOfWeek.MONDAY).toString();
            default -> date.toString();
        };
    }

    private List<String> orderedBucketKeys(LocalDate from, LocalDate to, String granularity) {
        List<String> keys = new ArrayList<>();
        if ("MONTH".equals(granularity)) {
            YearMonth start = YearMonth.from(from);
            YearMonth end = YearMonth.from(to);
            for (YearMonth ym = start; !ym.isAfter(end); ym = ym.plusMonths(1)) {
                keys.add(ym.toString());
            }
        } else if ("WEEK".equals(granularity)) {
            LocalDate cursor = from.with(java.time.DayOfWeek.MONDAY);
            if (cursor.isBefore(from)) cursor = cursor.plusWeeks(1);
            while (!cursor.isAfter(to)) {
                keys.add(cursor.toString());
                cursor = cursor.plusWeeks(1);
            }
        } else {
            for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
                keys.add(d.toString());
            }
        }
        return keys;
    }

    private String bucketLabel(String key, String granularity) {
        if ("MONTH".equals(granularity)) {
            YearMonth ym = YearMonth.parse(key);
            return String.format("Tháng %02d/%d", ym.getMonthValue(), ym.getYear());
        }
        if ("WEEK".equals(granularity)) {
            LocalDate start = LocalDate.parse(key);
            LocalDate end = start.plusDays(6);
            return start.format(DMY) + " – " + end.format(DMY);
        }
        return LocalDate.parse(key).format(DMY);
    }

    private Map<String, Object> computeKpi(List<Map<String, Object>> rows) {
        int total = rows.size();
        int passed = (int) rows.stream().filter(r -> Boolean.TRUE.equals(r.get("passed"))).count();
        int failed = total - passed;
        Map<String, Object> kpi = new LinkedHashMap<>();
        kpi.put("total", total);
        kpi.put("passed", passed);
        kpi.put("failed", failed);
        kpi.put("complianceRate", complianceRate(total, passed));
        kpi.put("hasData", total > 0);
        kpi.put("complianceRateLabel", total == 0 ? "Chưa có dữ liệu" : formatRate(complianceRate(total, passed)));
        return kpi;
    }

    private Map<String, Object> toDetailRow(QtktEvaluation e, ReportKind kind) {
        boolean passed = isPassed(e, kind);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", e.getId());
        m.put("evalDate", e.getEvalDate().toString());
        m.put("evalDateLabel", e.getEvalDate().format(DMY));
        m.put("departmentId", e.getDepartment().getId());
        m.put("departmentName", e.getDepartment().getName());
        m.put("employeeId", e.getEmployee().getId());
        m.put("employeeName", e.getEmployee().getFullName());
        m.put("employeeCode", e.getEmployee().getEmployeeCode());
        m.put("procedureCode", e.getProcedureCode());
        m.put("procedureName", e.getProcedureName());
        m.put("checkContextCode", e.getCheckContextCode());
        m.put("checkContextLabel", e.getCheckContextLabel());
        m.put("patientCode", e.getPatientCode() != null && !e.getPatientCode().isBlank() ? e.getPatientCode() : null);
        m.put("totalScore", e.getTotalScore());
        m.put("maxScore", e.getMaxScore());
        m.put("passed", passed);
        m.put("result", passed ? "Đạt" : "Không đạt");
        return m;
    }

    private boolean isPassed(QtktEvaluation e, ReportKind kind) {
        if (kind == ReportKind.HAND_HYGIENE) {
            return e.getTotalScore().compareTo(HAND_WASH_PASS_SCORE) == 0;
        }
        if (kind == ReportKind.GDSK) {
            return isGdskPassed(e);
        }
        return e.getTotalScore().compareTo(TECHNICAL_PASS_MIN) >= 0;
    }

    private boolean isGdskPassed(QtktEvaluation e) {
        BigDecimal min = templateService.passMinScore(GDSK_COUNSELING);
        if (e.getTotalScore().compareTo(min) < 0) {
            return false;
        }
        Map<String, Double> maxByStep = templateService.stepMaxPoints(GDSK_COUNSELING);
        Map<String, Double> scores = parseScores(e.getScoresJson());
        for (String stepId : templateService.requiredFullStepIds(GDSK_COUNSELING)) {
            double max = maxByStep.getOrDefault(stepId, 0d);
            double got = scores.getOrDefault(stepId, 0d);
            if (BigDecimal.valueOf(got).compareTo(BigDecimal.valueOf(max)) < 0) {
                return false;
            }
        }
        return true;
    }

    private Map<String, Double> parseScores(String json) {
        if (json == null || json.isBlank()) return Map.of();
        try {
            return objectMapper.readValue(json, new TypeReference<>() {});
        } catch (Exception ex) {
            return Map.of();
        }
    }

    private Double complianceRate(int total, int passed) {
        if (total == 0) return null;
        return BigDecimal.valueOf(passed * 100.0 / total)
                .setScale(2, RoundingMode.HALF_UP)
                .doubleValue();
    }

    private String formatRate(Double rate) {
        if (rate == null) return "Chưa có dữ liệu";
        return String.format(Locale.ROOT, "%.2f%%", rate);
    }

    private List<Map<String, Object>> filterDetails(List<Map<String, Object>> rows, String search, String resultFilter) {
        String q = search != null ? search.trim().toLowerCase(Locale.ROOT) : "";
        String rf = normalizeResultFilter(resultFilter);
        return rows.stream()
                .filter(r -> {
                    if ("PASS".equals(rf) && !Boolean.TRUE.equals(r.get("passed"))) return false;
                    if ("FAIL".equals(rf) && Boolean.TRUE.equals(r.get("passed"))) return false;
                    if (q.isEmpty()) return true;
                    String name = String.valueOf(r.get("employeeName")).toLowerCase(Locale.ROOT);
                    String code = String.valueOf(r.get("employeeCode")).toLowerCase(Locale.ROOT);
                    String patient = String.valueOf(r.get("patientCode") != null ? r.get("patientCode") : "")
                            .toLowerCase(Locale.ROOT);
                    return name.contains(q) || code.contains(q) || patient.contains(q);
                })
                .toList();
    }

    private List<Map<String, Object>> sortDetails(List<Map<String, Object>> rows, String sortDir) {
        Comparator<Map<String, Object>> cmp = Comparator.comparing(r -> String.valueOf(r.get("evalDate")));
        if ("ASC".equals(normalizeSortDir(sortDir))) {
            return rows.stream().sorted(cmp).toList();
        }
        return rows.stream().sorted(cmp.reversed()).toList();
    }

    private Map<String, Object> paginate(List<Map<String, Object>> rows, int page, int size) {
        int safeSize = Math.max(1, Math.min(size, 200));
        int safePage = Math.max(0, page);
        int total = rows.size();
        int fromIdx = Math.min(safePage * safeSize, total);
        int toIdx = Math.min(fromIdx + safeSize, total);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("items", rows.subList(fromIdx, toIdx));
        out.put("total", total);
        out.put("page", safePage);
        out.put("size", safeSize);
        out.put("totalPages", safeSize == 0 ? 0 : (int) Math.ceil(total / (double) safeSize));
        return out;
    }

    private List<String> resolveProcedureCodes(ReportKind kind, String procedureCode) {
        if (kind == ReportKind.HAND_HYGIENE) {
            return List.of(HAND_WASH);
        }
        if (kind == ReportKind.GDSK) {
            return List.of(GDSK_COUNSELING);
        }
        if (procedureCode != null && !procedureCode.isBlank()) {
            String code = procedureCode.trim().toUpperCase(Locale.ROOT);
            if (!TECHNICAL_PROCEDURES.contains(code)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Quy trình không hợp lệ");
            }
            return List.of(code);
        }
        return TECHNICAL_PROCEDURES;
    }

    private List<Department> departmentsForReport(ReportKind kind) {
        List<Department> all = accessibleNursingDepartments();
        if (kind != ReportKind.GDSK) {
            return all;
        }
        return all.stream()
                .filter(d -> templateService.isDepartmentAllowedForProcedure(GDSK_COUNSELING, d.getName()))
                .toList();
    }

    private String procedureName(String code) {
        try {
            return String.valueOf(templateService.requireProcedure(code).get("name"));
        } catch (Exception ex) {
            return code;
        }
    }

    private DateRange resolveRange(LocalDate from, LocalDate to) {
        LocalDate f = from != null ? from : YearMonth.now().atDay(1);
        LocalDate t = to != null ? to : LocalDate.now();
        if (f.isAfter(t)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Khoảng ngày không hợp lệ");
        }
        return new DateRange(f, t);
    }

    private void validateDepartmentAccess(Long departmentId) {
        if (departmentId == null) return;
        boolean ok = accessibleNursingDepartments().stream().anyMatch(d -> d.getId().equals(departmentId));
        if (!ok) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem khoa này");
        }
    }

    private String resolveDepartmentLabel(Long departmentId) {
        if (departmentId == null) return "Toàn viện";
        return accessibleNursingDepartments().stream()
                .filter(d -> d.getId().equals(departmentId))
                .map(Department::getName)
                .findFirst()
                .orElse("Khoa #" + departmentId);
    }

    private String resolveEmployeeLabel(Long employeeId) {
        if (employeeId == null) return "Tất cả";
        return employeeRepository.findById(employeeId)
                .map(Employee::getFullName)
                .orElse("NV #" + employeeId);
    }

    private UserAccount ensureCanAccess() {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && actor.getRole() != UserRole.HEAD_NURSING
                && actor.getRole() != UserRole.HEAD_DEPARTMENT) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền truy cập báo cáo tuân thủ");
        }
        return actor;
    }

    private boolean isNursingOfficeOrAdmin(UserAccount actor) {
        return actor.getRole() == UserRole.ADMIN || actor.getRole() == UserRole.HEAD_NURSING;
    }

    List<Department> accessibleNursingDepartments() {
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

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listFilterEmployees(Long departmentId) {
        validateDepartmentAccess(departmentId);
        List<Department> depts = accessibleNursingDepartments();
        List<Employee> employees = new ArrayList<>();
        for (Department d : depts) {
            if (departmentId != null && !d.getId().equals(departmentId)) continue;
            employees.addAll(employeeRepository.findByDepartment_IdAndStatus(
                    d.getId(), EmployeeStatus.ACTIVE, Sort.by("fullName")));
        }
        return employees.stream()
                .filter(NursingBlockClassifier::matches)
                .map(e -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", e.getId());
                    m.put("fullName", e.getFullName());
                    m.put("employeeCode", e.getEmployeeCode());
                    m.put("departmentId", e.getDepartment() != null ? e.getDepartment().getId() : null);
                    m.put("departmentName", e.getDepartment() != null ? e.getDepartment().getName() : null);
                    return m;
                })
                .toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listFilterDepartments() {
        return listFilterDepartments(null);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listFilterDepartments(String reportKind) {
        List<Department> depts = accessibleNursingDepartments();
        if (reportKind != null && "GDSK".equalsIgnoreCase(reportKind.trim())) {
            depts = depts.stream()
                    .filter(d -> templateService.isDepartmentAllowedForProcedure(GDSK_COUNSELING, d.getName()))
                    .toList();
        }
        return depts.stream()
                .map(d -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", d.getId());
                    m.put("code", d.getCode());
                    m.put("name", d.getName());
                    return m;
                })
                .toList();
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static String normalizeResultFilter(String s) {
        if (s == null || s.isBlank()) return "ALL";
        return s.trim().toUpperCase(Locale.ROOT);
    }

    private static String normalizeSortDir(String s) {
        if (s == null || s.isBlank()) return "DESC";
        return s.trim().toUpperCase(Locale.ROOT);
    }

    private record DateRange(LocalDate from, LocalDate to) {}
}
