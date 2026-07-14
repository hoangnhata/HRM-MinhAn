package com.minhan.hrm.service;

import com.minhan.hrm.dto.salary.ComputedSalaryGradeDto;
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

    @Transactional
    public EmployeeSalaryProfileDto getProfile(Long employeeId) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanViewSalary(emp);
        EmployeeSalaryProfile profile = profileRepository.findByEmployee(emp).orElse(null);
        if (profile != null && profile.getSalaryCategory() != null) {
            checkAndNotifyGradeIncrease(emp, profile);
        }
        return buildDto(emp, profile, canEditSalary());
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public EmployeeSalaryProfileDto upsertProfile(Long employeeId, EmployeeSalaryProfileRequest req) {
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
    public int recalculateAll() {
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
    public List<Map<String, Object>> exportAllProfiles() {
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
                    "attractionSalary", dto.getProfessionalAttractionSalary(),
                    "totalSalary", dto.getTotalSalary()));
        }
        return rows;
    }

    private EmployeeSalaryProfileDto buildDto(Employee emp, EmployeeSalaryProfile profile, boolean canEdit) {
        LocalDate calcDate = profile != null && profile.getSeniorityAsOfDate() != null
                ? profile.getSeniorityAsOfDate()
                : LocalDate.now();
        BigDecimal yearsOfService = salaryCalculator.calculateWorkingYears(emp.getHireDate(), calcDate);
        boolean doctor = profile != null && profile.getSalaryCategory() == SalaryCategory.DOCTOR;
        BigDecimal seniority = profile != null
                ? salaryCalculator.calculateSalarySeniority(
                yearsOfService,
                profile.getPriorRaiseYears(),
                profile.getDegreeConversionYears(),
                doctor)
                : yearsOfService;
        ComputedSalaryGradeDto grade = profile != null && profile.getSalaryCategory() != null
                ? salaryCalculator.computeForProfile(emp, profile)
                : SalaryCalculatorService.emptyGrade();
        grade = applyImportedSalaries(grade, profile);
        BigDecimal attraction = profile != null ? profile.getProfessionalAttractionSalary() : BigDecimal.ZERO;
        BigDecimal total = salaryCalculator.calculateFinalSalary(
                grade.getInsuranceSalary(), grade.getProductSalary(), attraction);

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
                .priorRaiseYears(profile != null ? profile.getPriorRaiseYears() : BigDecimal.ZERO)
                .professionalAttractionSalary(attraction)
                .computedGrade(grade)
                .totalSalary(total)
                .canViewSensitive(true)
                .canEdit(canEdit)
                .build();
    }

    /**
     * Ưu tiên lương import từ Excel thâm niên; nếu không có hoặc không hợp lệ thì dùng thang bảng lương.
     */
    private ComputedSalaryGradeDto applyImportedSalaries(
            ComputedSalaryGradeDto grade, EmployeeSalaryProfile profile) {
        if (profile == null) {
            return grade;
        }
        BigDecimal insurance = grade.getInsuranceSalary();
        BigDecimal product = grade.getProductSalary();
        if (SalaryAmounts.isPlausibleSalary(profile.getImportedInsuranceSalary())) {
            insurance = profile.getImportedInsuranceSalary();
        }
        if (SalaryAmounts.isPlausibleSalary(profile.getImportedProductSalary())) {
            product = profile.getImportedProductSalary();
        }
        if (insurance.equals(grade.getInsuranceSalary()) && product.equals(grade.getProductSalary())) {
            return grade;
        }
        BigDecimal scaleTotal = insurance.add(product);
        return ComputedSalaryGradeDto.builder()
                .gradeLevel(grade.getGradeLevel())
                .gradeLabel(grade.getGradeLabel())
                .yearsRange(grade.getYearsRange())
                .coefficient(grade.getCoefficient())
                .insuranceSalary(insurance)
                .productSalary(product)
                .scaleSalary(scaleTotal.compareTo(BigDecimal.ZERO) > 0 ? scaleTotal : grade.getScaleSalary())
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
        profile.setPriorRaiseYears(defaultZero(req.getPriorRaiseYears()));
        profile.setProfessionalAttractionSalary(defaultZero(req.getProfessionalAttractionSalary()));
    }

    private void assertCanViewSalary(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() == UserRole.ADMIN || current.getRole() == UserRole.HR) {
            return;
        }
        Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
        if (self == null || !self.getId().equals(target.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem bảng lương");
        }
    }

    private boolean canEditSalary() {
        UserRole role = employeeService.currentUser().getRole();
        return role == UserRole.ADMIN || role == UserRole.HR;
    }

    private static BigDecimal defaultZero(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }
}
