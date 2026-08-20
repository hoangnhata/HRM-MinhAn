package com.minhan.hrm.service;

import com.minhan.hrm.dto.salary.ComputedSalaryGradeDto;
import com.minhan.hrm.dto.salary.EarlyRaiseConversionDto;
import com.minhan.hrm.dto.salary.EmployeeSalaryProfileDto;
import com.minhan.hrm.dto.salary.EmployeeSalaryProfileRequest;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeSalaryProfileRepository;
import com.minhan.hrm.salary.SalaryAmounts;
import com.minhan.hrm.salary.SalaryQualifications;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class EmployeeSalaryProfileService {

    private final EmployeeSalaryProfileRepository profileRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeService employeeService;
    private final SalaryCalculatorService salaryCalculator;
    private final NotificationService notificationService;
    private final SalaryAccessService salaryAccessService;

    @Transactional
    public EmployeeSalaryProfileDto getProfile(Long employeeId, String salaryToken) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        boolean adminUnlocked = assertCanViewSalary(emp, salaryToken);
        EmployeeSalaryProfile profile = profileRepository.findByEmployee(emp).orElse(null);
        if (profile != null && profile.getSalaryCategory() != null) {
            checkAndNotifyGradeIncrease(emp, profile);
        }
        return buildDto(emp, profile, adminUnlocked);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public EmployeeSalaryProfileDto upsertProfile(
            Long employeeId, EmployeeSalaryProfileRequest req, String salaryToken) {
        salaryAccessService.requireAdminGrant(salaryToken);
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        validateRequest(req);
        EmployeeSalaryProfile profile = profileRepository.findByEmployee(emp).orElseGet(() ->
                EmployeeSalaryProfile.builder().employee(emp).build());
        int oldGrade = profile.getId() != null && profile.getLastNotifiedGrade() > 0
                ? profile.getLastNotifiedGrade()
                : resolveCurrentGrade(emp, profile);
        applyRequest(profile, req);
        profile = profileRepository.save(profile);
        checkAndNotifyGradeIncrease(emp, profile, oldGrade);
        return buildDto(emp, profile, true);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public int recalculateAll(String salaryToken) {
        salaryAccessService.requireAdminGrant(salaryToken);
        int count = 0;
        for (Employee emp : employeeRepository.findAll()) {
            profileRepository.findByEmployee(emp).ifPresent(p -> {
                if (p.getSalaryCategory() != null) {
                    profileRepository.save(p);
                }
            });
            count++;
        }
        return count;
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional(readOnly = true)
    public List<Map<String, Object>> exportAllProfiles(String salaryToken) {
        salaryAccessService.requireAdminGrant(salaryToken);
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Employee emp : employeeRepository.findAll()) {
            EmployeeSalaryProfile profile = profileRepository.findByEmployee(emp).orElse(null);
            if (profile == null || profile.getSalaryCategory() == null) {
                continue;
            }
            EmployeeSalaryProfileDto dto = buildDto(emp, profile, false);
            rows.add(Map.of(
                    "employeeCode", emp.getEmployeeCode() != null ? emp.getEmployeeCode() : "",
                    "fullName", emp.getFullName(),
                    "department", emp.getDepartment().getName(),
                    "yearsOfService", dto.getYearsOfService(),
                    "seniorityYears", dto.getSeniorityYears(),
                    "grade", dto.getComputedGrade().getGradeLabel(),
                    "insuranceSalary", dto.getComputedGrade().getInsuranceSalary(),
                    "productSalary", dto.getComputedGrade().getProductSalary(),
                    "attractionSalary", BigDecimal.ZERO,
                    "totalSalary", dto.getTotalSalary()));
        }
        return rows;
    }

    private EmployeeSalaryProfileDto buildDto(Employee emp, EmployeeSalaryProfile profile, boolean canEdit) {
        LocalDate today = LocalDate.now();
        LocalDate scaleStart = profile != null ? profile.getSalaryScaleStartDate() : null;
        BigDecimal yearsOfService = salaryCalculator.calculateWorkingYears(scaleStart, today);
        BigDecimal seniority = salaryCalculator.resolveSeniorityYears(emp, profile, today);
        ComputedSalaryGradeDto grade = profile != null && profile.getSalaryCategory() != null
                ? salaryCalculator.computeForProfile(emp, profile)
                : SalaryCalculatorService.emptyGrade();
        // LĐG đã gắn lương import; còn lại: ưu tiên thang bảng lương, fallback lương import.
        if (profile == null || !profile.isLdg()) {
            grade = applyImportedSalaries(grade, profile);
        }
        BigDecimal attraction = BigDecimal.ZERO;
        BigDecimal total = salaryCalculator.calculateFinalSalary(
                grade.getInsuranceSalary(), grade.getProductSalary(), attraction);
        // Bác sỹ: thang chỉ có tổng — nếu chưa tách BH/SP thì dùng tổng thang.
        if (total.compareTo(BigDecimal.ZERO) <= 0
                && grade.getScaleSalary() != null
                && grade.getScaleSalary().compareTo(BigDecimal.ZERO) > 0) {
            total = grade.getScaleSalary();
        }

        return EmployeeSalaryProfileDto.builder()
                .employeeId(emp.getId())
                .salaryCategory(profile != null && profile.getSalaryCategory() != null
                        ? profile.getSalaryCategory().name() : null)
                .employeeBlock(profile != null && profile.getEmployeeBlock() != null
                        ? profile.getEmployeeBlock().name() : null)
                .qualification(profile != null ? salaryCalculator.resolveQualification(profile) : null)
                .tierGroup(profile != null ? profile.getTierGroup() : 3)
                .doctorQualificationCode(profile != null ? profile.getDoctorQualificationCode() : null)
                .qualificationNote(profile != null ? profile.getQualificationNote() : null)
                .yearsOfService(yearsOfService)
                .seniorityYears(seniority)
                .degreeConversionYears(profile != null ? profile.getDegreeConversionYears() : BigDecimal.ZERO)
                .priorRaiseYears(profile != null ? salaryCalculator.earlyRaiseYears(profile) : BigDecimal.ZERO)
                .earlyRaiseConversions(resolveEarlyRaiseList(profile))
                .professionalAttractionSalary(BigDecimal.ZERO)
                .salaryScaleStartDate(profile != null ? profile.getSalaryScaleStartDate() : null)
                .seniorityAsOfDate(profile != null ? profile.getSeniorityAsOfDate() : null)
                .baseSeniorityYears(profile != null ? profile.getBaseSeniorityYears() : null)
                .ldg(profile != null && profile.isLdg())
                .importedInsuranceSalary(profile != null ? profile.getImportedInsuranceSalary() : null)
                .importedProductSalary(profile != null ? profile.getImportedProductSalary() : null)
                .computedGrade(grade)
                .totalSalary(total)
                .canViewSensitive(true)
                .canEdit(canEdit)
                .build();
    }

    /**
     * Nhân viên thường ưu tiên số tách BH/SP trên thang, thiếu mới dùng số import.
     * Bác sĩ ưu tiên tổng lương theo bậc; lương cơ bản import giữ nguyên và phần
     * đảm bảo sản phẩm = tổng theo thang - lương cơ bản.
     */
    private ComputedSalaryGradeDto applyImportedSalaries(
            ComputedSalaryGradeDto grade, EmployeeSalaryProfile profile) {
        if (profile == null) {
            return grade;
        }
        BigDecimal insurance = grade.getInsuranceSalary();
        BigDecimal product = grade.getProductSalary();
        boolean doctor = profile.getSalaryCategory() == SalaryCategory.DOCTOR;

        if (doctor) {
            BigDecimal importedBase = profile.getImportedInsuranceSalary();
            if (SalaryAmounts.isPlausibleSalary(importedBase)) {
                insurance = importedBase;
            }
            BigDecimal scaleTotal = grade.getScaleSalary() != null
                    ? grade.getScaleSalary() : BigDecimal.ZERO;
            if (!SalaryAmounts.isPlausibleSalary(scaleTotal)) {
                throw new ApiException(HttpStatus.CONFLICT,
                        "Thang bảng lương bác sĩ chưa có tổng lương hợp lệ cho bậc hiện tại");
            }
            if (insurance.compareTo(scaleTotal) > 0) {
                throw new ApiException(HttpStatus.CONFLICT,
                        "Lương cơ bản bác sĩ đang lớn hơn tổng lương trong thang bậc");
            }
            // Tuyệt đối ưu tiên tổng theo thang. Không dùng lương đảm bảo sản phẩm
            // import cũ làm fallback vì sẽ khiến tổng lương lệch khỏi bậc hiện tại.
            product = scaleTotal.subtract(insurance);
            return ComputedSalaryGradeDto.builder()
                    .gradeLevel(grade.getGradeLevel())
                    .gradeLabel(grade.getGradeLabel())
                    .yearsRange(grade.getYearsRange())
                    .coefficient(grade.getCoefficient())
                    .insuranceSalary(insurance)
                    .productSalary(product)
                    .scaleSalary(scaleTotal)
                    .build();
        }

        boolean scaleInsuranceOk = SalaryAmounts.isPlausibleSalary(insurance);
        boolean scaleProductOk = SalaryAmounts.isPlausibleSalary(product);
        if (!scaleInsuranceOk) {
            if (SalaryAmounts.isPlausibleSalary(profile.getImportedInsuranceSalary())) {
                insurance = profile.getImportedInsuranceSalary();
            }
        }
        if (!scaleProductOk) {
            if (SalaryAmounts.isPlausibleSalary(profile.getImportedProductSalary())) {
                product = profile.getImportedProductSalary();
            }
        }
        if (insurance.equals(grade.getInsuranceSalary()) && product.equals(grade.getProductSalary())) {
            return grade;
        }
        BigDecimal splitTotal = insurance.add(product);
        BigDecimal scaleTotal = grade.getScaleSalary() != null && grade.getScaleSalary().compareTo(BigDecimal.ZERO) > 0
                ? grade.getScaleSalary()
                : splitTotal;
        return ComputedSalaryGradeDto.builder()
                .gradeLevel(grade.getGradeLevel())
                .gradeLabel(grade.getGradeLabel())
                .yearsRange(grade.getYearsRange())
                .coefficient(grade.getCoefficient())
                .insuranceSalary(insurance)
                .productSalary(product)
                .scaleSalary(scaleTotal)
                .build();
    }

    private int resolveCurrentGrade(Employee emp, EmployeeSalaryProfile profile) {
        if (profile == null || profile.getSalaryCategory() == null) {
            return 0;
        }
        ComputedSalaryGradeDto g = salaryCalculator.computeForProfile(emp, profile);
        return g.getGradeLevel();
    }

    private void checkAndNotifyGradeIncrease(Employee emp, EmployeeSalaryProfile profile) {
        checkAndNotifyGradeIncrease(emp, profile, profile.getLastNotifiedGrade());
    }

    private void checkAndNotifyGradeIncrease(Employee emp, EmployeeSalaryProfile profile, int oldGrade) {
        if (profile.getSalaryCategory() != SalaryCategory.EMPLOYEE) {
            return;
        }
        ComputedSalaryGradeDto g = salaryCalculator.computeForProfile(emp, profile);
        int newGrade = g.getGradeLevel();
        if (newGrade <= 0) {
            return;
        }
        int baseline = oldGrade > 0 ? oldGrade : profile.getLastNotifiedGrade();
        if (newGrade > baseline) {
            notificationService.notifySalaryGradeIncrease(
                    emp.getUser(), emp, baseline, newGrade, salaryCalculator.yearsRangeForGrade(newGrade));
            profile.setLastNotifiedGrade(newGrade);
            profileRepository.save(profile);
        } else if (profile.getLastNotifiedGrade() == 0 && newGrade > 0) {
            profile.setLastNotifiedGrade(newGrade);
            profileRepository.save(profile);
        }
    }

    private void validateRequest(EmployeeSalaryProfileRequest req) {
        if (req.getSalaryCategory() == SalaryCategory.EMPLOYEE) {
            if (req.getEmployeeBlock() == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Nhân viên cần chọn khối trực tiếp hoặc gián tiếp");
            }
            if (req.getQualification() == null || req.getQualification().isBlank()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Nhân viên cần chọn trình độ");
            }
        }
        if (req.getSalaryCategory() == SalaryCategory.DOCTOR
                && (req.getDoctorQualificationCode() == null || req.getDoctorQualificationCode().isBlank())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Bác sỹ cần chọn trình độ thang bảng lương");
        }
        if (req.getSalaryScaleStartDate() == null
                && req.getBaseSeniorityYears() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Cần chọn ngày bắt đầu tính thang bảng lương hoặc nhập thâm niên mốc 30/06");
        }
    }

    private static void applyRequest(EmployeeSalaryProfile profile, EmployeeSalaryProfileRequest req) {
        profile.setSalaryCategory(req.getSalaryCategory());
        profile.setEmployeeBlock(req.getSalaryCategory() == SalaryCategory.EMPLOYEE
                ? req.getEmployeeBlock() : null);
        if (req.getQualification() != null && !req.getQualification().isBlank()) {
            profile.setQualification(SalaryQualifications.normalizeQualification(req.getQualification()));
            profile.setTierGroup(SalaryQualifications.tierGroupFromQualification(profile.getQualification()));
        } else if (req.getTierGroup() > 0) {
            profile.setTierGroup(req.getTierGroup());
            profile.setQualification(SalaryQualifications.fromTierGroup(req.getTierGroup()));
        }
        profile.setDoctorQualificationCode(req.getSalaryCategory() == SalaryCategory.DOCTOR
                ? req.getDoctorQualificationCode() : null);
        profile.setQualificationNote(req.getQualificationNote());
        profile.setDegreeConversionYears(defaultZero(req.getDegreeConversionYears()));
        applyEarlyRaiseConversions(profile, req);
        profile.setProfessionalAttractionSalary(BigDecimal.ZERO);
        profile.setSalaryScaleStartDate(req.getSalaryScaleStartDate());
        // Form luôn gửi đủ 2 trường mốc; null = bỏ mốc, tính từ ngày bắt đầu thang.
        // base = 0 kèm ngày bắt đầu thang cũng coi như không có mốc.
        if (Boolean.TRUE.equals(req.getLdg())) {
            profile.setBaseSeniorityYears(null);
            profile.setSeniorityAsOfDate(null);
        } else if (SalaryCalculatorService.hasSeniorityMilestone(
                req.getBaseSeniorityYears(), req.getSalaryScaleStartDate())) {
            profile.setBaseSeniorityYears(req.getBaseSeniorityYears());
            profile.setSeniorityAsOfDate(
                    req.getSeniorityAsOfDate() != null
                            ? req.getSeniorityAsOfDate()
                            : LocalDate.of(2026, 6, 30));
        } else {
            profile.setBaseSeniorityYears(null);
            profile.setSeniorityAsOfDate(null);
        }
        if (req.getLdg() != null) {
            profile.setLdg(req.getLdg());
            if (Boolean.TRUE.equals(req.getLdg())) {
                profile.setFixedGradeLabel(
                        req.getFixedGradeLabel() != null && !req.getFixedGradeLabel().isBlank()
                                ? req.getFixedGradeLabel().trim()
                                : "LĐG");
            } else {
                profile.setFixedGradeLabel(null);
            }
        }
        if (req.getImportedInsuranceSalary() != null) {
            profile.setImportedInsuranceSalary(req.getImportedInsuranceSalary());
        }
        if (req.getImportedProductSalary() != null) {
            profile.setImportedProductSalary(req.getImportedProductSalary());
        }
    }

    private boolean assertCanViewSalary(Employee target, String salaryToken) {
        UserAccount current = employeeService.currentUser();
        Employee self = employeeService.linkedEmployee(current).orElse(null);
        if (self != null && self.getId().equals(target.getId())) {
            if (!employeeService.canViewOwnSalary(self)) {
                throw new ApiException(HttpStatus.FORBIDDEN,
                        "Nhân viên thử việc chưa có ngày vào làm chính thức — chưa xem được bảng lương");
            }
            return false;
        }
        if (current.getRole() == UserRole.ADMIN || current.getRole() == UserRole.HR) {
            salaryAccessService.requireAdminGrant(salaryToken);
            return true;
        }
        if (self == null || !self.getId().equals(target.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem bảng lương");
        }
        return false;
    }

    private static void applyEarlyRaiseConversions(EmployeeSalaryProfile profile, EmployeeSalaryProfileRequest req) {
        if (req.getEarlyRaiseConversions() != null) {
            List<EarlyRaiseConversionDto> cleaned = req.getEarlyRaiseConversions().stream()
                    .filter(e -> e != null && e.getRaiseDate() != null && e.getYears() != null)
                    .map(e -> EarlyRaiseConversionDto.builder()
                            .raiseDate(e.getRaiseDate())
                            .years(e.getYears().max(BigDecimal.ZERO))
                            .build())
                    .sorted(Comparator.comparing(EarlyRaiseConversionDto::getRaiseDate))
                    .toList();
            profile.setEarlyRaiseConversions(new ArrayList<>(cleaned));
            BigDecimal sum = cleaned.stream()
                    .map(EarlyRaiseConversionDto::getYears)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            profile.setPriorRaiseYears(sum);
            return;
        }
        if (req.getPriorRaiseYears() != null) {
            profile.setPriorRaiseYears(defaultZero(req.getPriorRaiseYears()));
        }
    }

    private static List<EarlyRaiseConversionDto> resolveEarlyRaiseList(EmployeeSalaryProfile profile) {
        if (profile == null) {
            return List.of();
        }
        if (profile.getEarlyRaiseConversions() != null && !profile.getEarlyRaiseConversions().isEmpty()) {
            return profile.getEarlyRaiseConversions().stream()
                    .filter(e -> e != null && e.getRaiseDate() != null)
                    .toList();
        }
        return List.of();
    }

    private static BigDecimal defaultZero(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }
}
