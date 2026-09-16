package com.minhan.hrm.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.NursingDailyReportRepository;
import com.minhan.hrm.repository.QtktEvaluationRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.service.DepartmentService;
import com.minhan.hrm.service.NursingBlockClassifier;
import com.minhan.hrm.service.QtktTemplateService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;

/**
 * Seed dữ liệu ảo báo cáo ĐD hằng ngày + đánh giá QTKT để test Module A / compliance.
 * Bật tạm: {@code DEMO_SEED=true} hoặc {@code --minhan.hrm.demo-seed.enabled=true}, rồi restart.
 * Idempotent — bỏ qua bản ghi đã tồn tại theo unique key.
 * Tắt lại sau khi test xong (không để bật lâu trên production).
 */
@Slf4j
@Component
@Order(Integer.MAX_VALUE)
@RequiredArgsConstructor
public class NursingQtktDemoSeedRunner implements ApplicationRunner {

    private static final String[] TECH_PROCEDURES = {"IV_INJECTION", "IV_INFUSION", "IV_CATHETER"};
    private static final String[] HW_CONTEXTS = {
            "BEFORE_PATIENT", "BEFORE_ASEPTIC", "AFTER_FLUID", "AFTER_PATIENT", "AFTER_SURROUNDINGS"
    };
    private static final String[] HW_LABELS = {
            "Trước khi tiếp xúc với người bệnh",
            "Trước khi làm thủ thuật vô khuẩn",
            "Sau khi tiếp xúc với dịch tiết hoặc máu",
            "Sau khi tiếp xúc với người bệnh",
            "Sau khi tiếp xúc với môi trường xung quanh người bệnh"
    };

    private final HrmProperties hrmProperties;
    private final DepartmentService departmentService;
    private final EmployeeRepository employeeRepository;
    private final NursingDailyReportRepository nursingDailyReportRepository;
    private final QtktEvaluationRepository qtktEvaluationRepository;
    private final UserAccountRepository userAccountRepository;
    private final QtktTemplateService qtktTemplateService;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (hrmProperties.getDemoSeed() == null || !hrmProperties.getDemoSeed().isEnabled()) {
            return;
        }
        log.info("Demo seed BAT — đang tạo dữ liệu ảo Module A / QTKT (tắt DEMO_SEED sau khi test)");
        UserAccount admin = userAccountRepository.findByUsername("admin").orElse(null);
        if (admin == null) {
            log.warn("Demo seed: không có user admin — bỏ qua");
            return;
        }

        List<Department> depts = departmentService.listNursingHeadScopeDepartments();
        if (depts.isEmpty()) {
            log.warn("Demo seed: chưa có khoa khối ĐD — bỏ qua");
            return;
        }

        YearMonth ym = YearMonth.now();
        LocalDate from = ym.atDay(1);
        LocalDate to = LocalDate.now().isBefore(ym.atEndOfMonth()) ? LocalDate.now() : ym.atEndOfMonth();

        int ndr = seedNursingDaily(depts, from, to, admin);
        int qtkt = seedQtkt(depts, from, to, admin);
        log.info("Demo seed xong: nursing_daily_reports +{}, qtkt_evaluations +{} ({} → {})",
                ndr, qtkt, from, to);
    }

    private int seedNursingDaily(List<Department> depts, LocalDate from, LocalDate to, UserAccount admin) {
        int created = 0;
        for (Department dept : depts) {
            int baseBeds = 18 + (int) (dept.getId() % 15);
            for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
                if (nursingDailyReportRepository.existsByDepartment_IdAndReportDate(dept.getId(), d)) {
                    continue;
                }
                int day = d.getDayOfMonth();
                int hash = (int) ((dept.getId() * 31L + day) % 100);
                int plannedBeds = baseBeds;
                int actualBeds = Math.max(12, plannedBeds - (hash % 3));
                int inpatients = Math.max(8, actualBeds - (hash % 5));
                int totalStaff = 8 + (int) (dept.getId() % 6);
                int plannedLeave = hash % 3 == 0 ? 1 : 0;
                int unplannedLeave = hash % 11 == 0 ? 1 : 0;
                int maternityLeave = hash % 17 == 0 ? 1 : 0;
                int workingStaff = Math.max(4, totalStaff - plannedLeave - unplannedLeave - maternityLeave);
                int falls = hash % 9 == 0 ? 1 : (hash % 23 == 0 ? 2 : 0);
                int ulcers = hash % 13 == 0 ? 1 : 0;
                int idMix = hash % 19 == 0 ? 1 : 0;
                int medErr = hash % 15 == 0 ? 1 : 0;

                nursingDailyReportRepository.save(NursingDailyReport.builder()
                        .department(dept)
                        .reportDate(d)
                        .totalStaff(totalStaff)
                        .workingStaff(workingStaff)
                        .plannedLeave(plannedLeave)
                        .unplannedLeave(unplannedLeave)
                        .maternityLeave(maternityLeave)
                        .longLeave(0)
                        .dutyAfternoonOff(hash % 7 == 0 ? 1 : 0)
                        .externalMission(hash % 21 == 0 ? 1 : 0)
                        .inpatients(inpatients)
                        .outpatients(20 + hash % 40)
                        .paraclinical(5 + hash % 15)
                        .surgery(dept.getName() != null && dept.getName().toUpperCase(Locale.ROOT).contains("NGOẠI")
                                ? 2 + hash % 4 : hash % 5)
                        .dischargedYesterday(1 + hash % 4)
                        .actualBeds(actualBeds)
                        .plannedBeds(plannedBeds)
                        .inpatientTreatmentDays(inpatients)
                        .falls(falls)
                        .newPressureUlcers(ulcers)
                        .idMixups(idMix)
                        .medicationErrors(medErr)
                        .demo(true)
                        .status(NursingDailyReportStatus.SUBMITTED)
                        .submittedAt(d.atStartOfDay(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant())
                        .createdBy(admin)
                        .build());
                created++;
            }
        }
        return created;
    }

    private int seedQtkt(List<Department> depts, LocalDate from, LocalDate to, UserAccount admin) {
        int created = 0;
        Instant now = Instant.now();
        int deptIdx = 0;
        for (Department dept : depts) {
            List<Employee> nurses = employeeRepository
                    .findByDepartment_IdAndStatus(dept.getId(), EmployeeStatus.ACTIVE, Sort.by("fullName"))
                    .stream()
                    .filter(NursingBlockClassifier::matches)
                    .limit(3)
                    .toList();
            if (nurses.isEmpty()) {
                deptIdx++;
                continue;
            }

            // ~8 ngày rải trong kỳ cho mỗi khoa
            List<LocalDate> sampleDays = sampleDates(from, to, 8, deptIdx);
            int n = 0;
            for (LocalDate evalDate : sampleDays) {
                Employee emp = nurses.get(n % nurses.size());
                String techCode = TECH_PROCEDURES[n % TECH_PROCEDURES.length];
                boolean pass = n % 4 != 3;
                created += insertQtktIfAbsent(emp, dept, techCode, "", null, "", evalDate, pass, admin, now);

                if (n % 2 == 0) {
                    int ctx = (n + deptIdx) % HW_CONTEXTS.length;
                    boolean hwPass = n % 3 != 2;
                    created += insertQtktIfAbsent(
                            emp, dept, "HAND_WASH", HW_CONTEXTS[ctx], HW_LABELS[ctx], "",
                            evalDate, hwPass, admin, now);
                }
                n++;
            }

            // Phiếu tư vấn GDSK — chỉ khoa lâm sàng được phép
            if (qtktTemplateService.isDepartmentAllowedForProcedure("GDSK_COUNSELING", dept.getName())) {
                List<LocalDate> gdskDays = sampleDates(from, to, 10, deptIdx + 17);
                int g = 0;
                for (LocalDate evalDate : gdskDays) {
                    Employee emp = nurses.get(g % nurses.size());
                    // Nhiều BN / ngày: 1–2 phiếu
                    int patients = 1 + (g % 2);
                    for (int p = 0; p < patients; p++) {
                        String patientCode = String.format("BN%02d%02d%02d",
                                dept.getId() % 100, evalDate.getDayOfMonth(), g * 10 + p + 1);
                        boolean gdskPass = (g + p) % 5 != 4; // ~80% đạt
                        created += insertQtktIfAbsent(
                                emp, dept, "GDSK_COUNSELING", "", null, patientCode,
                                evalDate, gdskPass, admin, now);
                    }
                    g++;
                }
            }
            deptIdx++;
        }
        return created;
    }

    private int insertQtktIfAbsent(
            Employee emp,
            Department dept,
            String procedureCode,
            String ctxCode,
            String ctxLabel,
            String patientCode,
            LocalDate evalDate,
            boolean pass,
            UserAccount admin,
            Instant now) {
        String context = ctxCode != null ? ctxCode : "";
        String patient = patientCode != null ? patientCode.trim() : "";
        if (qtktEvaluationRepository
                .findByEmployee_IdAndProcedureCodeAndEvalDateAndCheckContextCodeAndPatientCode(
                        emp.getId(), procedureCode, evalDate, context, patient)
                .isPresent()) {
            return 0;
        }

        Map<String, Double> max = qtktTemplateService.stepMaxPoints(procedureCode);
        Map<String, Double> scores = new LinkedHashMap<>();
        List<String> keys = new ArrayList<>(max.keySet());
        double total = 0;
        for (int i = 0; i < keys.size(); i++) {
            String k = keys.get(i);
            double v = max.get(k);
            if (!pass) {
                if ("GDSK_COUNSELING".equals(procedureCode) && "GDSK_12".equals(k)) {
                    v = 0; // thiếu tiêu chí bắt buộc → Không đạt
                } else if (!"GDSK_COUNSELING".equals(procedureCode) && i == keys.size() - 1) {
                    v = 0;
                } else if (!"GDSK_COUNSELING".equals(procedureCode)
                        && !"HAND_WASH".equals(procedureCode)
                        && i == keys.size() - 2) {
                    v = Math.max(0, v * 0.4);
                }
            }
            scores.put(k, v);
            total += v;
        }
        BigDecimal totalScore = BigDecimal.valueOf(total).setScale(2, RoundingMode.HALF_UP);
        String procedureName = String.valueOf(qtktTemplateService.requireProcedure(procedureCode).get("name"));

        try {
            qtktEvaluationRepository.save(QtktEvaluation.builder()
                    .employee(emp)
                    .department(dept)
                    .procedureCode(procedureCode)
                    .procedureName(procedureName)
                    .checkContextCode(context)
                    .checkContextLabel(ctxLabel)
                    .patientCode(patient)
                    .evalDate(evalDate)
                    .scoresJson(objectMapper.writeValueAsString(scores))
                    .totalScore(totalScore)
                    .maxScore(BigDecimal.TEN)
                    .note("Dữ liệu demo test" + (!patient.isBlank() ? " · Mã BN " + patient : ""))
                    .demo(true)
                    .status(QtktEvaluationStatus.SUBMITTED)
                    .createdBy(admin)
                    .updatedBy(admin)
                    .submittedAt(now)
                    .createdAt(now)
                    .updatedAt(now)
                    .build());
            return 1;
        } catch (Exception ex) {
            log.warn("Demo seed QTKT bỏ qua {} / {} / {}: {}", emp.getId(), procedureCode, evalDate, ex.getMessage());
            return 0;
        }
    }

    private static List<LocalDate> sampleDates(LocalDate from, LocalDate to, int count, int salt) {
        long days = java.time.temporal.ChronoUnit.DAYS.between(from, to) + 1;
        if (days <= 0) return List.of();
        int n = (int) Math.min(count, days);
        List<LocalDate> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            int offset = (int) ((i * (days / Math.max(1, n)) + salt * 2L) % days);
            out.add(from.plusDays(offset));
        }
        out.sort(Comparator.naturalOrder());
        return out.stream().distinct().toList();
    }
}
