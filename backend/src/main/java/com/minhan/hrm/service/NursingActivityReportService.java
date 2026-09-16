package com.minhan.hrm.service;

import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.NursingDailyReport;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.NursingDailyReportRepository;
import lombok.RequiredArgsConstructor;
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
public class NursingActivityReportService {

    public enum ReportKind {
        OVERVIEW,
        FALLS,
        PRESSURE_ULCER,
        NURSE_BED,
        ID_MIXUP,
        MEDICATION_ERROR
    }

    public enum CompareMetric {
        FALL_RATE,
        FALL_FREQUENCY,
        PRESSURE_RATE,
        PRESSURE_FREQUENCY,
        NURSE_BED,
        ID_MIXUP_FREQUENCY,
        MEDICATION_RATE
    }

    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final NursingDailyReportRepository reportRepository;
    private final DepartmentRepository departmentRepository;
    private final DepartmentService departmentService;
    private final EmployeeService employeeService;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listFilterDepartments() {
        return accessibleNursingDepartments().stream()
                .map(d -> Map.<String, Object>of("id", d.getId(), "code", d.getCode(), "name", d.getName()))
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> overview(LocalDate from, LocalDate to, Long departmentId, CompareMetric compareMetric) {
        return buildBundle(ReportKind.OVERVIEW, from, to, departmentId, compareMetric, null, null);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> fallsReport(
            LocalDate from, LocalDate to, Long departmentId, String sortBy, String sortDir) {
        return buildBundle(ReportKind.FALLS, from, to, departmentId, null, sortBy, sortDir);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> pressureUlcerReport(
            LocalDate from, LocalDate to, Long departmentId, String sortBy, String sortDir) {
        return buildBundle(ReportKind.PRESSURE_ULCER, from, to, departmentId, null, sortBy, sortDir);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> nurseBedReport(
            LocalDate from, LocalDate to, Long departmentId, String sortBy, String sortDir) {
        return buildBundle(ReportKind.NURSE_BED, from, to, departmentId, null, sortBy, sortDir);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> idMixupReport(
            LocalDate from, LocalDate to, Long departmentId, String sortBy, String sortDir) {
        return buildBundle(ReportKind.ID_MIXUP, from, to, departmentId, null, sortBy, sortDir);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> medicationErrorReport(
            LocalDate from, LocalDate to, Long departmentId, String sortBy, String sortDir) {
        return buildBundle(ReportKind.MEDICATION_ERROR, from, to, departmentId, null, sortBy, sortDir);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> departmentDetail(Long departmentId, LocalDate from, LocalDate to) {
        ensureCanAccess();
        validateDepartmentAccess(departmentId);
        DateRange range = normalizeRange(from, to);
        List<NursingDailyReport> reports = loadReports(range, departmentId);
        AggregatedMetrics totals = aggregate(reports);
        Department dept = departmentRepository.findById(departmentId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy khoa"));

        Map<String, Object> out = baseMeta(ReportKind.OVERVIEW, range, departmentId, dept.getName());
        out.put("rawTotals", totals.toMap());
        out.put("metrics", totals.toMetricsMap());
        out.put("dailyRows", reports.stream().map(this::toDailyRow).toList());
        return out;
    }

    private Map<String, Object> buildBundle(
            ReportKind kind,
            LocalDate from,
            LocalDate to,
            Long departmentId,
            CompareMetric compareMetric,
            String sortBy,
            String sortDir) {
        UserAccount actor = ensureCanAccess();
        validateDepartmentAccess(departmentId);
        DateRange range = normalizeRange(from, to);
        List<NursingDailyReport> reports = loadReports(range, departmentId);
        AggregatedMetrics totals = aggregate(reports);

        List<Department> scopeDepts = departmentId != null
                ? accessibleNursingDepartments().stream().filter(d -> d.getId().equals(departmentId)).toList()
                : accessibleNursingDepartments();

        Map<Long, List<NursingDailyReport>> byDept = reports.stream()
                .collect(Collectors.groupingBy(r -> r.getDepartment().getId(), LinkedHashMap::new, Collectors.toList()));

        List<Map<String, Object>> byDepartment = scopeDepts.stream()
                .map(d -> {
                    AggregatedMetrics m = aggregate(byDept.getOrDefault(d.getId(), List.of()));
                    Map<String, Object> row = new LinkedHashMap<>(m.toMetricsMap());
                    row.put("departmentId", d.getId());
                    row.put("departmentName", d.getName());
                    row.put("reportDays", m.reportDays);
                    return row;
                })
                .toList();

        if (kind != ReportKind.NURSE_BED && kind != ReportKind.OVERVIEW) {
            byDepartment = sortDepartmentRows(byDepartment, kind, sortBy, sortDir);
        } else if (kind == ReportKind.NURSE_BED) {
            byDepartment = sortNurseBedRows(byDepartment, sortDir);
        }

        CompareMetric metric = compareMetric != null ? compareMetric : CompareMetric.FALL_RATE;
        Map<String, Object> out = baseMeta(kind, range, departmentId, resolveDepartmentLabel(departmentId));
        out.put("kpi", buildKpi(kind, totals));
        out.put("overviewKpi", kind == ReportKind.OVERVIEW ? buildOverviewKpi(totals) : null);
        out.put("byDepartment", byDepartment);
        out.put("summaryTable", buildSummaryTable(scopeDepts, byDept));
        out.put("trend", buildMultiTrend(reports, range, kind));
        out.put("trendGranularity", trendGranularity(range.from(), range.to()));
        out.put("compareChart", buildCompareChart(byDepartment, metric));
        out.put("compareMetric", metric.name());
        out.put("actorRole", actor.getRole().name());
        out.put("reportDays", totals.reportDays);
        return out;
    }

    private Map<String, Object> buildOverviewKpi(AggregatedMetrics t) {
        Map<String, Object> m = t.toMetricsMap();
        Map<String, Object> cards = new LinkedHashMap<>();
        cards.put("falls", card(
                "rate", m.get("fallRate"),
                "rateLabel", m.get("fallRateLabel"),
                "frequency", m.get("fallFrequency"),
                "frequencyLabel", m.get("fallFrequencyLabel")));
        cards.put("pressureUlcers", card(
                "rate", m.get("pressureUlcerRate"),
                "rateLabel", m.get("pressureUlcerRateLabel"),
                "frequency", m.get("pressureUlcerFrequency"),
                "frequencyLabel", m.get("pressureUlcerFrequencyLabel")));
        cards.put("nurseBed", card(
                "ratio", m.get("nurseBedRatio"),
                "ratioLabel", m.get("nurseBedRatioLabel")));
        cards.put("idMixups", card(
                "frequency", m.get("idMixupFrequency"),
                "frequencyLabel", m.get("idMixupFrequencyLabel")));
        cards.put("medicationErrors", card(
                "rate", m.get("medicationErrorRate"),
                "rateLabel", m.get("medicationErrorRateLabel")));
        return cards;
    }

    /** Map.of không cho phép null — KPI có thể null khi chưa đủ mẫu số. */
    private static Map<String, Object> card(Object... keyValues) {
        Map<String, Object> out = new LinkedHashMap<>();
        for (int i = 0; i < keyValues.length; i += 2) {
            out.put((String) keyValues[i], keyValues[i + 1]);
        }
        return out;
    }

    private Map<String, Object> buildKpi(ReportKind kind, AggregatedMetrics t) {
        Map<String, Object> all = t.toMetricsMap();
        Map<String, Object> kpi = new LinkedHashMap<>();
        kpi.put("reportDays", t.reportDays);
        switch (kind) {
            case FALLS -> {
                kpi.put("falls", t.falls);
                kpi.put("inpatients", t.inpatients);
                kpi.put("inpatientTreatmentDays", t.inpatientTreatmentDays);
                kpi.put("fallRate", all.get("fallRate"));
                kpi.put("fallRateLabel", all.get("fallRateLabel"));
                kpi.put("fallFrequency", all.get("fallFrequency"));
                kpi.put("fallFrequencyLabel", all.get("fallFrequencyLabel"));
            }
            case PRESSURE_ULCER -> {
                kpi.put("newPressureUlcers", t.newPressureUlcers);
                kpi.put("inpatients", t.inpatients);
                kpi.put("inpatientTreatmentDays", t.inpatientTreatmentDays);
                kpi.put("pressureUlcerRate", all.get("pressureUlcerRate"));
                kpi.put("pressureUlcerRateLabel", all.get("pressureUlcerRateLabel"));
                kpi.put("pressureUlcerFrequency", all.get("pressureUlcerFrequency"));
                kpi.put("pressureUlcerFrequencyLabel", all.get("pressureUlcerFrequencyLabel"));
            }
            case NURSE_BED -> {
                kpi.put("workingStaff", t.workingStaff);
                kpi.put("inpatients", t.inpatients);
                kpi.put("nurseBedRatio", all.get("nurseBedRatio"));
                kpi.put("nurseBedRatioLabel", all.get("nurseBedRatioLabel"));
            }
            case ID_MIXUP -> {
                kpi.put("idMixups", t.idMixups);
                kpi.put("inpatientTreatmentDays", t.inpatientTreatmentDays);
                kpi.put("idMixupFrequency", all.get("idMixupFrequency"));
                kpi.put("idMixupFrequencyLabel", all.get("idMixupFrequencyLabel"));
            }
            case MEDICATION_ERROR -> {
                kpi.put("medicationErrors", t.medicationErrors);
                kpi.put("inpatients", t.inpatients);
                kpi.put("medicationErrorRate", all.get("medicationErrorRate"));
                kpi.put("medicationErrorRateLabel", all.get("medicationErrorRateLabel"));
            }
            default -> kpi.putAll(all);
        }
        return kpi;
    }

    private List<Map<String, Object>> buildSummaryTable(
            List<Department> depts, Map<Long, List<NursingDailyReport>> byDept) {
        return depts.stream().map(d -> {
            AggregatedMetrics m = aggregate(byDept.getOrDefault(d.getId(), List.of()));
            Map<String, Object> row = new LinkedHashMap<>(m.toMetricsMap());
            row.put("departmentId", d.getId());
            row.put("departmentName", d.getName());
            return row;
        }).toList();
    }

    private List<Map<String, Object>> buildMultiTrend(
            List<NursingDailyReport> reports, DateRange range, ReportKind kind) {
        String granularity = trendGranularity(range.from(), range.to());
        Map<String, List<NursingDailyReport>> buckets = new LinkedHashMap<>();
        for (NursingDailyReport r : reports) {
            buckets.computeIfAbsent(bucketKey(r.getReportDate(), granularity), k -> new ArrayList<>()).add(r);
        }
        List<String> keys = orderedBucketKeys(range.from(), range.to(), granularity);
        List<Map<String, Object>> out = new ArrayList<>();
        for (String key : keys) {
            AggregatedMetrics m = aggregate(buckets.getOrDefault(key, List.of()));
            Map<String, Object> point = new LinkedHashMap<>(m.toMetricsMap());
            point.put("bucketKey", key);
            point.put("label", bucketLabel(key, granularity));
            point.put("hasData", m.reportDays > 0);
            if (kind == ReportKind.FALLS) {
                point.put("primaryValue", point.get("fallRate"));
                point.put("secondaryValue", point.get("fallFrequency"));
            } else if (kind == ReportKind.PRESSURE_ULCER) {
                point.put("primaryValue", point.get("pressureUlcerRate"));
                point.put("secondaryValue", point.get("pressureUlcerFrequency"));
            } else if (kind == ReportKind.ID_MIXUP) {
                point.put("primaryValue", point.get("idMixupFrequency"));
            } else if (kind == ReportKind.MEDICATION_ERROR) {
                point.put("primaryValue", point.get("medicationErrorRate"));
            }
            out.add(point);
        }
        return out;
    }

    private List<Map<String, Object>> buildCompareChart(
            List<Map<String, Object>> byDepartment, CompareMetric metric) {
        return byDepartment.stream()
                .filter(r -> {
                    Object v = metricValue(r, metric);
                    return v instanceof Number;
                })
                .sorted(Comparator.comparingDouble(r -> -((Number) metricValue(r, metric)).doubleValue()))
                .map(r -> Map.<String, Object>of(
                        "departmentId", r.get("departmentId"),
                        "departmentName", r.get("departmentName"),
                        "value", metricValue(r, metric),
                        "valueLabel", metricLabel(r, metric)))
                .toList();
    }

    private Object metricValue(Map<String, Object> row, CompareMetric metric) {
        return switch (metric) {
            case FALL_RATE -> row.get("fallRate");
            case FALL_FREQUENCY -> row.get("fallFrequency");
            case PRESSURE_RATE -> row.get("pressureUlcerRate");
            case PRESSURE_FREQUENCY -> row.get("pressureUlcerFrequency");
            case NURSE_BED -> row.get("nurseBedRatio");
            case ID_MIXUP_FREQUENCY -> row.get("idMixupFrequency");
            case MEDICATION_RATE -> row.get("medicationErrorRate");
        };
    }

    private String metricLabel(Map<String, Object> row, CompareMetric metric) {
        return switch (metric) {
            case FALL_RATE -> String.valueOf(row.get("fallRateLabel"));
            case FALL_FREQUENCY -> String.valueOf(row.get("fallFrequencyLabel"));
            case PRESSURE_RATE -> String.valueOf(row.get("pressureUlcerRateLabel"));
            case PRESSURE_FREQUENCY -> String.valueOf(row.get("pressureUlcerFrequencyLabel"));
            case NURSE_BED -> String.valueOf(row.get("nurseBedRatioLabel"));
            case ID_MIXUP_FREQUENCY -> String.valueOf(row.get("idMixupFrequencyLabel"));
            case MEDICATION_RATE -> String.valueOf(row.get("medicationErrorRateLabel"));
        };
    }

    private List<Map<String, Object>> sortDepartmentRows(
            List<Map<String, Object>> rows, ReportKind kind, String sortBy, String sortDir) {
        boolean desc = !"ASC".equalsIgnoreCase(sortDir);
        String field = switch (kind) {
            case FALLS -> "FREQUENCY".equalsIgnoreCase(sortBy) ? "fallFrequency" : "fallRate";
            case PRESSURE_ULCER -> "FREQUENCY".equalsIgnoreCase(sortBy) ? "pressureUlcerFrequency" : "pressureUlcerRate";
            case ID_MIXUP -> "idMixupFrequency";
            case MEDICATION_ERROR -> "medicationErrorRate";
            default -> "fallRate";
        };
        Comparator<Map<String, Object>> cmp = Comparator.comparingDouble(r -> {
            Object v = r.get(field);
            return v instanceof Number n ? n.doubleValue() : -1;
        });
        if (desc) cmp = cmp.reversed();
        return rows.stream().sorted(cmp).toList();
    }

    private List<Map<String, Object>> sortNurseBedRows(List<Map<String, Object>> rows, String sortDir) {
        boolean desc = !"ASC".equalsIgnoreCase(sortDir);
        Comparator<Map<String, Object>> cmp = Comparator.comparingDouble(r -> {
            Object v = r.get("nurseBedRatio");
            return v instanceof Number n ? n.doubleValue() : -1;
        });
        return (desc ? rows.stream().sorted(cmp.reversed()) : rows.stream().sorted(cmp)).toList();
    }

    private Map<String, Object> toDailyRow(NursingDailyReport r) {
        AggregatedMetrics one = aggregate(List.of(r));
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("reportDate", r.getReportDate().toString());
        m.put("reportDateLabel", r.getReportDate().format(DMY));
        m.put("inpatients", r.getInpatients());
        m.put("inpatientTreatmentDays", r.getInpatientTreatmentDays());
        m.put("falls", r.getFalls());
        m.put("newPressureUlcers", r.getNewPressureUlcers());
        m.put("idMixups", r.getIdMixups());
        m.put("medicationErrors", r.getMedicationErrors());
        m.put("totalStaff", r.getTotalStaff());
        m.put("workingStaff", r.getWorkingStaff());
        m.put("actualBeds", r.getActualBeds());
        m.put("metrics", one.toMetricsMap());
        return m;
    }

    private List<NursingDailyReport> loadReports(DateRange range, Long departmentId) {
        Set<Long> deptIds = accessibleNursingDepartments().stream().map(Department::getId).collect(Collectors.toSet());
        if (deptIds.isEmpty()) return List.of();
        if (departmentId != null) {
            if (!deptIds.contains(departmentId)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem báo cáo khoa này");
            }
            deptIds = Set.of(departmentId);
        }
        return reportRepository.findByDepartment_IdInAndReportDateBetweenOrderByReportDateAscDepartment_NameAsc(
                        deptIds, range.from(), range.to())
                .stream()
                .filter(r -> r.getStatus() == null
                        || r.getStatus() == com.minhan.hrm.entity.NursingDailyReportStatus.SUBMITTED)
                .toList();
    }

    private AggregatedMetrics aggregate(List<NursingDailyReport> reports) {
        AggregatedMetrics m = new AggregatedMetrics();
        for (NursingDailyReport r : reports) {
            m.falls += r.getFalls();
            m.newPressureUlcers += r.getNewPressureUlcers();
            m.idMixups += r.getIdMixups();
            m.medicationErrors += r.getMedicationErrors();
            m.inpatients += r.getInpatients();
            m.inpatientTreatmentDays += r.getInpatientTreatmentDays();
            m.totalStaff += r.getTotalStaff();
            m.workingStaff += r.getWorkingStaff();
            m.actualBeds += r.getActualBeds();
            m.reportDays++;
        }
        return m;
    }

    private Map<String, Object> baseMeta(
            ReportKind kind, DateRange range, Long departmentId, String departmentName) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("reportKind", kind.name());
        out.put("reportTitle", reportTitle(kind));
        out.put("from", range.from().toString());
        out.put("to", range.to().toString());
        out.put("fromLabel", range.from().format(DMY));
        out.put("toLabel", range.to().format(DMY));
        out.put("yearMonth", YearMonth.from(range.from()).toString());
        out.put("departmentId", departmentId);
        out.put("departmentName", departmentName != null ? departmentName : "Toàn viện");
        return out;
    }

    private String reportTitle(ReportKind kind) {
        return switch (kind) {
            case OVERVIEW -> "Báo cáo hoạt động điều dưỡng — Tổng quan";
            case FALLS -> "Báo cáo tỷ lệ té ngã";
            case PRESSURE_ULCER -> "Báo cáo tỷ lệ loét tì đè";
            case NURSE_BED -> "Báo cáo tỷ lệ điều dưỡng/người bệnh";
            case ID_MIXUP -> "Báo cáo nhầm lẫn xác định người bệnh";
            case MEDICATION_ERROR -> "Báo cáo tỷ lệ sai sót do dùng thuốc";
        };
    }

    private String resolveDepartmentLabel(Long departmentId) {
        if (departmentId == null) return "Toàn viện";
        return departmentRepository.findById(departmentId).map(Department::getName).orElse("—");
    }

    private DateRange normalizeRange(LocalDate from, LocalDate to) {
        LocalDate f = from != null ? from : YearMonth.now().atDay(1);
        LocalDate t = to != null ? to : LocalDate.now();
        if (f.isAfter(t)) throw new ApiException(HttpStatus.BAD_REQUEST, "Từ ngày phải trước đến ngày");
        return new DateRange(f, t);
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
            for (YearMonth ym = start; !ym.isAfter(end); ym = ym.plusMonths(1)) keys.add(ym.toString());
        } else if ("WEEK".equals(granularity)) {
            LocalDate cursor = from.with(java.time.DayOfWeek.MONDAY);
            while (!cursor.isAfter(to)) {
                keys.add(cursor.toString());
                cursor = cursor.plusWeeks(1);
            }
        } else {
            for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) keys.add(d.toString());
        }
        return keys;
    }

    private String bucketLabel(String key, String granularity) {
        if ("MONTH".equals(granularity)) {
            YearMonth ym = YearMonth.parse(key);
            return "T" + ym.getMonthValue() + "/" + ym.getYear();
        }
        if ("WEEK".equals(granularity)) {
            LocalDate mon = LocalDate.parse(key);
            return mon.format(DMY);
        }
        return LocalDate.parse(key).format(DMY);
    }

    private static Double pct(int numerator, int denominator) {
        if (denominator <= 0) return null;
        return BigDecimal.valueOf(numerator * 100.0 / denominator).setScale(2, RoundingMode.HALF_UP).doubleValue();
    }

    private static Double per1000(int numerator, int denominator) {
        if (denominator <= 0) return null;
        return BigDecimal.valueOf(numerator * 1000.0 / denominator).setScale(2, RoundingMode.HALF_UP).doubleValue();
    }

    private static Double ratio(int numerator, int denominator) {
        if (denominator <= 0) return null;
        return BigDecimal.valueOf((double) numerator / denominator).setScale(2, RoundingMode.HALF_UP).doubleValue();
    }

    private static String pctLabel(Double v) {
        return v == null ? "Chưa đủ dữ liệu" : String.format(Locale.ROOT, "%.2f%%", v);
    }

    private static String per1000Label(Double v, String unit) {
        return v == null ? "Chưa đủ dữ liệu" : String.format(Locale.ROOT, "%.2f %s", v, unit);
    }

    private static String ratioLabel(Double v) {
        if (v == null) return "Không xác định";
        return String.format(Locale.ROOT, "%.2f điều dưỡng/người bệnh", v);
    }

    private UserAccount ensureCanAccess() {
        UserAccount actor = employeeService.currentUser();
        if (actor.getRole() != UserRole.ADMIN
                && actor.getRole() != UserRole.HEAD_NURSING
                && actor.getRole() != UserRole.HEAD_DEPARTMENT) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem báo cáo hoạt động điều dưỡng");
        }
        return actor;
    }

    private List<Department> accessibleNursingDepartments() {
        UserAccount actor = ensureCanAccess();
        List<Department> nursingDepts = actor.getRole() == UserRole.HEAD_NURSING
                ? departmentService.listNursingHeadScopeDepartments()
                : departmentService.listNursingBlockDepartments();
        if (actor.getRole() == UserRole.ADMIN || actor.getRole() == UserRole.HEAD_NURSING) {
            return nursingDepts;
        }
        Long scopedDept = employeeService.resolveHeadDepartmentScope(actor);
        if (scopedDept == null) return List.of();
        return nursingDepts.stream().filter(d -> Objects.equals(d.getId(), scopedDept)).toList();
    }

    private void validateDepartmentAccess(Long departmentId) {
        if (departmentId == null) return;
        boolean allowed = accessibleNursingDepartments().stream().anyMatch(d -> d.getId().equals(departmentId));
        if (!allowed) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem báo cáo khoa này");
        }
    }

    public record DateRange(LocalDate from, LocalDate to) {}

    private static class AggregatedMetrics {
        int falls;
        int newPressureUlcers;
        int idMixups;
        int medicationErrors;
        int inpatients;
        int inpatientTreatmentDays;
        int totalStaff;
        int workingStaff;
        int actualBeds;
        int reportDays;

        Map<String, Object> toMap() {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("falls", falls);
            m.put("newPressureUlcers", newPressureUlcers);
            m.put("idMixups", idMixups);
            m.put("medicationErrors", medicationErrors);
            m.put("inpatients", inpatients);
            m.put("inpatientTreatmentDays", inpatientTreatmentDays);
            m.put("totalStaff", totalStaff);
            m.put("workingStaff", workingStaff);
            m.put("actualBeds", actualBeds);
            m.put("reportDays", reportDays);
            return m;
        }

        Map<String, Object> toMetricsMap() {
            Double fallRate = pct(falls, inpatients);
            Double fallFreq = per1000(falls, inpatientTreatmentDays);
            Double puRate = pct(newPressureUlcers, inpatients);
            Double puFreq = per1000(newPressureUlcers, inpatientTreatmentDays);
            // Tỷ lệ ĐD/NB = điều dưỡng đi làm / người bệnh nội trú
            Double nbRatio = ratio(workingStaff, inpatients);
            Double idFreq = per1000(idMixups, inpatientTreatmentDays);
            Double medRate = pct(medicationErrors, inpatients);

            Map<String, Object> m = new LinkedHashMap<>(toMap());
            m.put("fallRate", fallRate);
            m.put("fallRateLabel", pctLabel(fallRate));
            m.put("fallFrequency", fallFreq);
            m.put("fallFrequencyLabel", per1000Label(fallFreq, "lượt té ngã/1.000 ngày điều trị"));
            m.put("pressureUlcerRate", puRate);
            m.put("pressureUlcerRateLabel", pctLabel(puRate));
            m.put("pressureUlcerFrequency", puFreq);
            m.put("pressureUlcerFrequencyLabel", per1000Label(puFreq, "ca loét mắc mới/1.000 ngày điều trị"));
            m.put("nurseBedRatio", nbRatio);
            m.put("nurseBedRatioLabel", ratioLabel(nbRatio));
            m.put("idMixupFrequency", idFreq);
            m.put("idMixupFrequencyLabel", per1000Label(idFreq, "sự cố/1.000 ngày điều trị"));
            m.put("medicationErrorRate", medRate);
            m.put("medicationErrorRateLabel", pctLabel(medRate));
            m.put("hasData", reportDays > 0);
            return m;
        }
    }
}
