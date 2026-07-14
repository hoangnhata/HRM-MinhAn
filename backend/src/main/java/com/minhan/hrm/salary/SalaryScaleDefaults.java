package com.minhan.hrm.salary;

import com.minhan.hrm.entity.SalaryScaleType;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Thang bảng lương 4.2025 — dùng khi DB chưa có dữ liệu import từ Excel.
 */
public final class SalaryScaleDefaults {

    public record GradeAmounts(
            BigDecimal coefficient,
            BigDecimal insuranceSalary,
            BigDecimal productSalary,
            BigDecimal totalIncome) {
    }

    private static final Map<String, GradeAmounts[]> DATA = new HashMap<>();

    static {
        put(SalaryScaleType.EMPLOYEE_INDIRECT, SalaryQualifications.DAI_HOC, indirectDaiHoc());
        put(SalaryScaleType.EMPLOYEE_INDIRECT, SalaryQualifications.CAO_DANG, indirectCaoDang());
        put(SalaryScaleType.EMPLOYEE_INDIRECT, SalaryQualifications.LAO_DONG, indirectLaoDong());
        put(SalaryScaleType.EMPLOYEE_DIRECT, SalaryQualifications.DAI_HOC, directDaiHoc());
        put(SalaryScaleType.EMPLOYEE_DIRECT, SalaryQualifications.CAO_DANG, directCaoDang());
        put(SalaryScaleType.EMPLOYEE_DIRECT, SalaryQualifications.LAO_DONG, directLaoDong());
    }

    private SalaryScaleDefaults() {
    }

    public static Optional<GradeAmounts> lookup(
            SalaryScaleType scaleType, String qualification, int gradeLevel) {
        if (scaleType == null || gradeLevel < 1 || gradeLevel > 10) {
            return Optional.empty();
        }
        String qual = SalaryQualifications.normalizeQualification(qualification);
        GradeAmounts[] grades = DATA.get(key(scaleType, qual));
        if (grades == null) {
            return Optional.empty();
        }
        return Optional.of(grades[gradeLevel - 1]);
    }

    private static void put(SalaryScaleType type, String qual, GradeAmounts[] grades) {
        DATA.put(key(type, qual), grades);
    }

    private static String key(SalaryScaleType type, String qual) {
        return type.name() + "|" + SalaryQualifications.normalizeQualification(qual);
    }

    private static GradeAmounts[] indirectDaiHoc() {
        return grades(
                row(1.10, 4770000, 510000, 5280000),
                row(1.20, 4850000, 910000, 5760000),
                row(1.30, 4930000, 1310000, 6240000),
                row(1.40, 5010000, 1710000, 6720000),
                row(1.50, 5100000, 2100000, 7200000),
                row(1.60, 5180000, 2500000, 7680000),
                row(1.70, 5260000, 2900000, 8160000),
                row(1.80, 5350000, 3290000, 8640000),
                row(1.90, 5430000, 3690000, 9120000),
                row(2.00, 5510000, 4090000, 9600000));
    }

    private static GradeAmounts[] indirectCaoDang() {
        return grades(
                row(1.05, 4430000, 610000, 5040000),
                row(1.15, 4520000, 1000000, 5520000),
                row(1.25, 4600000, 1400000, 6000000),
                row(1.35, 4680000, 1800000, 6480000),
                row(1.45, 4770000, 2190000, 6960000),
                row(1.55, 4850000, 2590000, 7440000),
                row(1.65, 4930000, 2990000, 7920000),
                row(1.75, 5010000, 3390000, 8400000),
                row(1.85, 5100000, 3780000, 8880000),
                row(1.95, 5180000, 4180000, 9360000));
    }

    private static GradeAmounts[] indirectLaoDong() {
        return grades(
                row(1.00, 4140000, 660000, 4800000),
                row(1.10, 4230000, 1050000, 5280000),
                row(1.20, 4310000, 1450000, 5760000),
                row(1.30, 4390000, 1850000, 6240000),
                row(1.40, 4480000, 2240000, 6720000),
                row(1.50, 4560000, 2640000, 7200000),
                row(1.60, 4640000, 3040000, 7680000),
                row(1.70, 4720000, 3440000, 8160000),
                row(1.80, 4810000, 3830000, 8640000),
                row(1.90, 4890000, 4230000, 9120000));
    }

    private static GradeAmounts[] directDaiHoc() {
        return grades(
                row(1.10, 4770000, 1280000, 6050000),
                row(1.20, 4850000, 1750000, 6600000),
                row(1.30, 4930000, 2220000, 7150000),
                row(1.40, 5010000, 2690000, 7700000),
                row(1.50, 5100000, 3150000, 8250000),
                row(1.60, 5180000, 3620000, 8800000),
                row(1.70, 5260000, 4090000, 9350000),
                row(1.80, 5350000, 4550000, 9900000),
                row(1.90, 5430000, 5020000, 10450000),
                row(2.00, 5510000, 5490000, 11000000));
    }

    private static GradeAmounts[] directCaoDang() {
        return grades(
                row(1.05, 4430000, 1345000, 5775000),
                row(1.15, 4520000, 1805000, 6325000),
                row(1.25, 4600000, 2275000, 6875000),
                row(1.35, 4680000, 2745000, 7425000),
                row(1.45, 4770000, 3205000, 7975000),
                row(1.55, 4850000, 3675000, 8525000),
                row(1.65, 4930000, 4145000, 9075000),
                row(1.75, 5010000, 4615000, 9625000),
                row(1.85, 5100000, 5075000, 10175000),
                row(1.95, 5180000, 5545000, 10725000));
    }

    private static GradeAmounts[] directLaoDong() {
        return grades(
                row(1.00, 4140000, 1360000, 5500000),
                row(1.10, 4230000, 1820000, 6050000),
                row(1.20, 4310000, 2290000, 6600000),
                row(1.30, 4390000, 2760000, 7150000),
                row(1.40, 4480000, 3220000, 7700000),
                row(1.50, 4560000, 3690000, 8250000),
                row(1.60, 4640000, 4160000, 8800000),
                row(1.70, 4720000, 4630000, 9350000),
                row(1.80, 4810000, 5090000, 9900000),
                row(1.90, 4890000, 5560000, 10450000));
    }

    private static GradeAmounts row(double coef, long insurance, long product, long total) {
        return new GradeAmounts(
                BigDecimal.valueOf(coef),
                BigDecimal.valueOf(insurance),
                BigDecimal.valueOf(product),
                BigDecimal.valueOf(total));
    }

    private static GradeAmounts[] grades(GradeAmounts... rows) {
        return rows;
    }
}
