package com.minhan.hrm.service;

import com.minhan.hrm.dto.salary.ComputedSalaryGradeDto;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.SalaryScaleDoctorEntryRepository;
import com.minhan.hrm.repository.SalaryScaleEntryRepository;
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
        if (joinDate == null) {
            return BigDecimal.ZERO;
        }
        LocalDate end = calculationDate != null ? calculationDate : LocalDate.now();
        long days = ChronoUnit.DAYS.between(joinDate, end);
        if (days < 0) {
            return BigDecimal.ZERO;
        }
        return BigDecimal.valueOf(days)
                .divide(BigDecimal.valueOf(365.25), 6, RoundingMode.HALF_UP);
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
        if (profile == null || profile.getSalaryCategory() == null) {
            return emptyGrade();
        }
        LocalDate calcDate = profile.getSeniorityAsOfDate() != null
                ? profile.getSeniorityAsOfDate()
                : LocalDate.now();
        BigDecimal workingYears = calculateWorkingYears(emp.getHireDate(), calcDate);
        boolean doctor = profile.getSalaryCategory() == SalaryCategory.DOCTOR;
        BigDecimal seniority = calculateSalarySeniority(
                workingYears,
                profile.getPriorRaiseYears(),
                profile.getDegreeConversionYears(),
                doctor);

        if (doctor) {
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
        List<SalaryScaleDoctorEntry> entries = doctorEntryRepository.findAllByOrderBySortOrderAsc();
        SalaryScaleDoctorEntry match = entries.stream()
                .filter(e -> qualificationCode != null
                        && qualificationCode.equalsIgnoreCase(e.getQualificationCode()))
                .filter(e -> matchesDoctorYears(e, seniorityYears))
                .findFirst()
                .orElse(null);
        if (match == null) {
            return emptyGrade();
        }
        return ComputedSalaryGradeDto.builder()
                .gradeLevel(0)
                .gradeLabel(match.getTimeLabel())
                .yearsRange(match.getTimeLabel())
                .coefficient(BigDecimal.ZERO)
                .insuranceSalary(BigDecimal.ZERO)
                .productSalary(BigDecimal.ZERO)
                .scaleSalary(match.getTotalSalary())
                .build();
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
        if (years.compareTo(e.getYearsMin()) < 0) {
            return false;
        }
        if (e.getYearsMax() == null) {
            return true;
        }
        return years.compareTo(e.getYearsMax()) < 0;
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
