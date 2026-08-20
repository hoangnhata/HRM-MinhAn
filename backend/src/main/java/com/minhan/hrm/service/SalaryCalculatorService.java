package com.minhan.hrm.service;

import com.minhan.hrm.dto.salary.ComputedSalaryGradeDto;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.SalaryScaleDoctorEntryRepository;
import com.minhan.hrm.repository.SalaryScaleEntryRepository;
import com.minhan.hrm.salary.DoctorQualifications;
import com.minhan.hrm.salary.SalaryQualifications;
import com.minhan.hrm.salary.SalaryScaleDefaults;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SalaryCalculatorService {

    private static final int MAX_GRADE = 10;

    private final SalaryScaleEntryRepository scaleEntryRepository;
    private final SalaryScaleDoctorEntryRepository doctorEntryRepository;

    public BigDecimal calculateWorkingYears(LocalDate joinDate, LocalDate calculationDate) {
        return yearsBetweenDays(joinDate, calculationDate);
    }

    /** Số năm = số ngày / 365 (làm tròn 6 chữ số). */
    public BigDecimal yearsBetweenDays(LocalDate start, LocalDate end) {
        if (start == null) {
            return BigDecimal.ZERO;
        }
        LocalDate to = end != null ? end : LocalDate.now();
        long days = ChronoUnit.DAYS.between(start, to);
        if (days < 0) {
            return BigDecimal.ZERO;
        }
        return BigDecimal.valueOf(days)
                .divide(BigDecimal.valueOf(365), 6, RoundingMode.HALF_UP);
    }

    /**
     * Thâm niên hiện tại từ snapshot Excel (vd. 30/06/2026):
     * {@code base + (today - asOfDate) / 365} — tự tăng mỗi ngày.
     */
    public BigDecimal calculateLiveSeniority(BigDecimal baseYears, LocalDate asOfDate, LocalDate today) {
        BigDecimal base = baseYears != null ? baseYears : BigDecimal.ZERO;
        if (asOfDate == null) {
            return base;
        }
        return base.add(yearsBetweenDays(asOfDate, today));
    }

    public BigDecimal calculateSalarySeniority(
            BigDecimal workingYears,
            BigDecimal priorRaiseYears,
            BigDecimal degreeConversionYears,
            boolean doctor) {
        BigDecimal w = workingYears != null ? workingYears : BigDecimal.ZERO;
        BigDecimal prior = priorRaiseYears != null ? priorRaiseYears : BigDecimal.ZERO;
        BigDecimal conv = doctor && degreeConversionYears != null ? degreeConversionYears : BigDecimal.ZERO;
        return w.add(prior).add(conv);
    }

    /**
     * Thâm niên tính lương:
     * <ul>
     *   <li>Có mốc Excel (vd. 30/06): {@code baseSeniorityYears + (today - asOf) / 365}</li>
     *   <li>Không có mốc (null/trống, hoặc 0 kèm ngày bắt đầu thang): {@code (today - salaryScaleStartDate) / 365}</li>
     * </ul>
     * Cộng thêm quy đổi nâng lương sớm / chuyển đổi bằng cấp (nếu có).
     */
    public BigDecimal resolveSeniorityYears(Employee emp, EmployeeSalaryProfile profile, LocalDate today) {
        LocalDate end = today != null ? today : LocalDate.now();
        if (profile == null || profile.isLdg()) {
            return BigDecimal.ZERO;
        }
        BigDecimal years;
        if (hasSeniorityMilestone(profile.getBaseSeniorityYears(), profile.getSalaryScaleStartDate())) {
            LocalDate asOf = profile.getSeniorityAsOfDate() != null
                    ? profile.getSeniorityAsOfDate()
                    : LocalDate.of(2026, 6, 30);
            years = calculateLiveSeniority(profile.getBaseSeniorityYears(), asOf, end);
        } else {
            years = yearsBetweenDays(profile.getSalaryScaleStartDate(), end);
        }
        years = years.add(earlyRaiseYears(profile));
        if (profile.getSalaryCategory() == SalaryCategory.DOCTOR
                && profile.getDegreeConversionYears() != null) {
            years = years.add(profile.getDegreeConversionYears());
        }
        return years;
    }

    /**
     * Có mốc thâm niên 30/06 khi base khác null.
     * Riêng base = 0 kèm ngày bắt đầu thang → coi như không có mốc (hay nhập 0 thay vì để trống).
     */
    public static boolean hasSeniorityMilestone(BigDecimal baseYears, LocalDate salaryScaleStartDate) {
        if (baseYears == null) {
            return false;
        }
        if (baseYears.compareTo(BigDecimal.ZERO) == 0 && salaryScaleStartDate != null) {
            return false;
        }
        return true;
    }

    /** Tổng hệ số năm quy đổi nâng lương sớm. */
    public BigDecimal earlyRaiseYears(EmployeeSalaryProfile profile) {
        if (profile == null) {
            return BigDecimal.ZERO;
        }
        if (profile.getEarlyRaiseConversions() != null && !profile.getEarlyRaiseConversions().isEmpty()) {
            return profile.getEarlyRaiseConversions().stream()
                    .map(e -> e.getYears() != null ? e.getYears() : BigDecimal.ZERO)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
        }
        return profile.getPriorRaiseYears() != null ? profile.getPriorRaiseYears() : BigDecimal.ZERO;
    }

    /**
     * 0–2 → Bậc 1; >2–4 → Bậc 2; …; >18 → Bậc 10.
     */
    public int calculateGrade(BigDecimal seniorityYears) {
        if (seniorityYears == null || seniorityYears.compareTo(BigDecimal.ZERO) <= 0) {
            return 1;
        }
        double s = seniorityYears.doubleValue();
        if (s <= 2) {
            return 1;
        }
        if (s <= 4) {
            return 2;
        }
        if (s <= 6) {
            return 3;
        }
        if (s <= 8) {
            return 4;
        }
        if (s <= 10) {
            return 5;
        }
        if (s <= 12) {
            return 6;
        }
        if (s <= 14) {
            return 7;
        }
        if (s <= 16) {
            return 8;
        }
        if (s <= 18) {
            return 9;
        }
        return MAX_GRADE;
    }

    public String yearsRangeForGrade(int grade) {
        int g = Math.min(Math.max(grade, 1), MAX_GRADE);
        int minYears = (g - 1) * 2;
        int maxYears = g * 2;
        if (g >= MAX_GRADE) {
            return minYears + "+ năm";
        }
        return minYears + "-" + maxYears + " năm";
    }

    public ComputedSalaryGradeDto computeForProfile(Employee emp, EmployeeSalaryProfile profile) {
        return computeForProfileAtDate(emp, profile, LocalDate.now());
    }

    /** Tính bậc tại một ngày cụ thể, dùng cho kế hoạch nâng bậc theo tháng. */
    public ComputedSalaryGradeDto computeForProfileAtDate(
            Employee emp, EmployeeSalaryProfile profile, LocalDate calculationDate) {
        if (profile == null || profile.getSalaryCategory() == null) {
            return emptyGrade();
        }
        BigDecimal seniority = resolveSeniorityYears(emp, profile, calculationDate);

        if (profile.isLdg()) {
            String label = profile.getFixedGradeLabel() != null && !profile.getFixedGradeLabel().isBlank()
                    ? profile.getFixedGradeLabel()
                    : "LĐG";
            BigDecimal insurance = profile.getImportedInsuranceSalary() != null
                    ? profile.getImportedInsuranceSalary() : BigDecimal.ZERO;
            BigDecimal product = profile.getImportedProductSalary() != null
                    ? profile.getImportedProductSalary() : BigDecimal.ZERO;
            return ComputedSalaryGradeDto.builder()
                    .gradeLevel(0)
                    .gradeLabel(label)
                    .yearsRange(label)
                    .coefficient(BigDecimal.ZERO)
                    .insuranceSalary(insurance)
                    .productSalary(product)
                    .scaleSalary(insurance.add(product))
                    .build();
        }

        if (profile.getSalaryCategory() == SalaryCategory.DOCTOR) {
            return computeDoctorGrade(profile.getDoctorQualificationCode(), seniority);
        }
        if (profile.getEmployeeBlock() == null) {
            return emptyGrade();
        }
        SalaryScaleType scaleType = profile.getEmployeeBlock() == EmployeeSalaryBlock.DIRECT
                ? SalaryScaleType.EMPLOYEE_DIRECT
                : SalaryScaleType.EMPLOYEE_INDIRECT;
        String qualification = resolveQualification(profile);
        int grade = calculateGrade(seniority);
        return findEmployeeGrade(scaleType, qualification, grade);
    }

    public ComputedSalaryGradeDto findEmployeeGrade(
            SalaryScaleType scaleType, String qualification, int gradeLevel) {
        String qual = SalaryQualifications.normalizeQualification(qualification);
        return scaleEntryRepository
                .findByScaleTypeAndQualificationAndGradeLevel(scaleType, qual, gradeLevel)
                .map(e -> ComputedSalaryGradeDto.builder()
                        .gradeLevel(e.getGradeLevel())
                        .gradeLabel("BẬC " + e.getGradeLevel())
                        .yearsRange(yearsRangeForGrade(e.getGradeLevel()))
                        .coefficient(e.getCoefficient())
                        .insuranceSalary(e.getBaseInsuranceSalary())
                        .productSalary(e.getProductSalary())
                        .scaleSalary(e.getTotalIncome())
                        .build())
                .orElseGet(() -> SalaryScaleDefaults.lookup(scaleType, qual, gradeLevel)
                        .map(d -> ComputedSalaryGradeDto.builder()
                                .gradeLevel(gradeLevel)
                                .gradeLabel("BẬC " + gradeLevel)
                                .yearsRange(yearsRangeForGrade(gradeLevel))
                                .coefficient(d.coefficient())
                                .insuranceSalary(d.insuranceSalary())
                                .productSalary(d.productSalary())
                                .scaleSalary(d.totalIncome())
                                .build())
                        .orElseGet(() -> ComputedSalaryGradeDto.builder()
                                .gradeLevel(gradeLevel)
                                .gradeLabel("BẬC " + gradeLevel)
                                .yearsRange(yearsRangeForGrade(gradeLevel))
                                .coefficient(BigDecimal.ZERO)
                                .insuranceSalary(BigDecimal.ZERO)
                                .productSalary(BigDecimal.ZERO)
                                .scaleSalary(BigDecimal.ZERO)
                                .build()));
    }

    public BigDecimal calculateFinalSalary(
            BigDecimal insuranceSalary,
            BigDecimal productSalary,
            BigDecimal attractionSalary) {
        BigDecimal i = insuranceSalary != null ? insuranceSalary : BigDecimal.ZERO;
        BigDecimal p = productSalary != null ? productSalary : BigDecimal.ZERO;
        BigDecimal a = attractionSalary != null ? attractionSalary : BigDecimal.ZERO;
        return i.add(p).add(a);
    }

    public ComputedSalaryGradeDto computeDoctorGrade(String qualificationCode, BigDecimal seniorityYears) {
        String code = DoctorQualifications.normalize(qualificationCode);
        List<SalaryScaleDoctorEntry> entries = doctorEntryRepository.findAllByOrderBySortOrderAsc();
        SalaryScaleDoctorEntry match = entries.stream()
                .filter(e -> code != null && code.equalsIgnoreCase(e.getQualificationCode()))
                .filter(e -> matchesDoctorYears(e, seniorityYears))
                .findFirst()
                .orElse(null);
        if (match == null) {
            return emptyGrade();
        }
        // Thang BS theo khoảng thời gian (0-2 năm…), không dùng cặp «BẬC n · khoảng năm».
        return ComputedSalaryGradeDto.builder()
                .gradeLevel(doctorGradeLevel(match))
                .gradeLabel(match.getTimeLabel())
                .yearsRange(match.getTimeLabel())
                .coefficient(BigDecimal.ZERO)
                .insuranceSalary(BigDecimal.ZERO)
                .productSalary(BigDecimal.ZERO)
                .scaleSalary(match.getTotalSalary())
                .build();
    }

    private static int doctorGradeLevel(SalaryScaleDoctorEntry e) {
        if (e.getYearsMin() == null) {
            return 1;
        }
        if (e.getYearsMax() == null) {
            return 6;
        }
        // 0–2 → 1, 2–4 → 2, …
        int min = e.getYearsMin().intValue();
        return Math.min(10, Math.max(1, min / 2 + 1));
    }

    public String resolveQualification(EmployeeSalaryProfile profile) {
        if (profile.getQualification() != null && !profile.getQualification().isBlank()) {
            return SalaryQualifications.normalizeQualification(profile.getQualification());
        }
        return SalaryQualifications.fromTierGroup(profile.getTierGroup());
    }

    private static boolean matchesDoctorYears(SalaryScaleDoctorEntry e, BigDecimal years) {
        if (years == null) {
            return false;
        }
        BigDecimal min = e.getYearsMin() != null ? e.getYearsMin() : BigDecimal.ZERO;
        BigDecimal max = e.getYearsMax();
        // Thử việc: years_min = years_max = 0
        if (max != null && min.compareTo(max) == 0) {
            return years.compareTo(BigDecimal.ZERO) == 0 || years.compareTo(min) == 0;
        }
        if (years.compareTo(min) < 0) {
            return false;
        }
        if (max == null) {
            return true;
        }
        return years.compareTo(max) < 0;
    }

    public static ComputedSalaryGradeDto emptyGrade() {
        return ComputedSalaryGradeDto.builder()
                .gradeLevel(0)
                .gradeLabel("—")
                .yearsRange("—")
                .coefficient(BigDecimal.ZERO)
                .insuranceSalary(BigDecimal.ZERO)
                .productSalary(BigDecimal.ZERO)
                .scaleSalary(BigDecimal.ZERO)
                .build();
    }
}
