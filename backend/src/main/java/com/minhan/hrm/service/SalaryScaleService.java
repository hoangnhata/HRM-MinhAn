package com.minhan.hrm.service;

import com.minhan.hrm.dto.salary.*;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeSalaryBlock;
import com.minhan.hrm.entity.EmployeeSalaryProfile;
import com.minhan.hrm.entity.SalaryCategory;
import com.minhan.hrm.entity.SalaryScaleEntry;
import com.minhan.hrm.entity.SalaryScaleType;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeSalaryProfileRepository;
import com.minhan.hrm.repository.SalaryScaleDoctorEntryRepository;
import com.minhan.hrm.repository.SalaryScaleEntryRepository;
import com.minhan.hrm.salary.SalaryQualifications;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SalaryScaleService {

    private static final List<String> QUALIFICATION_ORDER = List.of(
            SalaryQualifications.DAI_HOC,
            SalaryQualifications.CAO_DANG,
            SalaryQualifications.LAO_DONG);

    private final SalaryScaleEntryRepository scaleEntryRepository;
    private final SalaryScaleDoctorEntryRepository doctorEntryRepository;
    private final SalaryCalculatorService salaryCalculator;
    private final EmployeeService employeeService;
    private final EmployeeSalaryProfileRepository salaryProfileRepository;
    private final SalaryAccessService salaryAccessService;

    @Transactional(readOnly = true)
    public Map<String, Object> getAllScales(String salaryToken, boolean mine) {
        String scope = resolveViewerScope(salaryToken, mine);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("viewerScope", scope);
        if ("ALL".equals(scope)) {
            out.put("employeeDirect", buildEmployeeScaleView(SalaryScaleType.EMPLOYEE_DIRECT));
            out.put("employeeIndirect", buildEmployeeScaleView(SalaryScaleType.EMPLOYEE_INDIRECT));
            out.put("doctor", listDoctorScale());
            out.put("entriesDirect", listEntriesInternal(SalaryScaleType.EMPLOYEE_DIRECT));
            out.put("entriesIndirect", listEntriesInternal(SalaryScaleType.EMPLOYEE_INDIRECT));
            return out;
        }
        out.put("employeeDirect", emptyEmployeeScale(SalaryScaleType.EMPLOYEE_DIRECT));
        out.put("employeeIndirect", emptyEmployeeScale(SalaryScaleType.EMPLOYEE_INDIRECT));
        out.put("doctor", List.of());
        out.put("entriesDirect", List.of());
        out.put("entriesIndirect", List.of());
        if ("DIRECT".equals(scope)) {
            out.put("employeeDirect", buildEmployeeScaleView(SalaryScaleType.EMPLOYEE_DIRECT));
            out.put("entriesDirect", listEntriesInternal(SalaryScaleType.EMPLOYEE_DIRECT));
        } else if ("INDIRECT".equals(scope)) {
            out.put("employeeIndirect", buildEmployeeScaleView(SalaryScaleType.EMPLOYEE_INDIRECT));
            out.put("entriesIndirect", listEntriesInternal(SalaryScaleType.EMPLOYEE_INDIRECT));
        } else if ("DOCTOR".equals(scope)) {
            out.put("doctor", listDoctorScale());
        }
        return out;
    }

    @Transactional(readOnly = true)
    public List<SalaryScaleEntryDto> listEntries(SalaryScaleType type, String salaryToken) {
        assertCanViewScaleType(type, salaryToken);
        return listEntriesInternal(type);
    }

    private List<SalaryScaleEntryDto> listEntriesInternal(SalaryScaleType type) {
        return scaleEntryRepository.findByScaleTypeOrderByQualificationAscGradeLevelAsc(type).stream()
                .map(this::toEntryDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public EmployeeScaleDto getEmployeeScale(SalaryScaleType type, String salaryToken) {
        assertCanViewScaleType(type, salaryToken);
        return buildEmployeeScaleView(type);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public EmployeeScaleDto updateEmployeeScaleBase(
            SalaryScaleType type, BigDecimal newBaseTotal, String qualification, String salaryToken) {
        salaryAccessService.requireAdminGrant(salaryToken);
        String qual = SalaryQualifications.normalizeQualification(qualification);
        SalaryScaleEntry base = scaleEntryRepository
                .findByScaleTypeAndQualificationAndGradeLevel(type, qual, 1)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy Bậc 1 của " + qual));
        BigDecimal oldTotal = base.getTotalIncome();
        if (oldTotal.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Tổng thu nhập Bậc 1 không hợp lệ");
        }
        if (newBaseTotal.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Tổng thu nhập mới phải lớn hơn 0");
        }
        BigDecimal ratio = newBaseTotal.divide(oldTotal, 8, RoundingMode.HALF_UP);
        List<SalaryScaleEntry> entries = scaleEntryRepository.findByScaleTypeOrderByQualificationAscGradeLevelAsc(type)
                .stream()
                .filter(e -> qual.equals(e.getQualification()))
                .toList();
        for (SalaryScaleEntry e : entries) {
            BigDecimal product = e.getProductSalary() != null ? e.getProductSalary() : BigDecimal.ZERO;
            BigDecimal newTotal = e.getTotalIncome().multiply(ratio).setScale(0, RoundingMode.HALF_UP);
            if (newTotal.compareTo(product) < 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Tổng thu nhập Bậc " + e.getGradeLevel() + " nhỏ hơn lương đảm bảo sản phẩm");
            }
            e.setTotalIncome(newTotal);
            e.setProductSalary(product);
            e.setBaseInsuranceSalary(newTotal.subtract(product));
            scaleEntryRepository.save(e);
        }
        return buildEmployeeScaleView(type);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public SalaryScaleEntryDto saveEntry(SalaryScaleEntryDto dto, String salaryToken) {
        salaryAccessService.requireAdminGrant(salaryToken);
        SalaryScaleType type = SalaryScaleType.valueOf(dto.getScaleType());
        String qual = SalaryQualifications.normalizeQualification(dto.getQualification());
        SalaryScaleEntry entry = scaleEntryRepository
                .findByScaleTypeAndQualificationAndGradeLevel(type, qual, dto.getGradeLevel())
                .orElseGet(() -> SalaryScaleEntry.builder()
                        .scaleType(type)
                        .qualification(qual)
                        .gradeLevel(dto.getGradeLevel())
                        .build());
        entry.setCoefficient(dto.getCoefficient());
        entry.setBaseInsuranceSalary(dto.getBaseInsuranceSalary());
        entry.setProductSalary(dto.getProductSalary());
        entry.setTotalIncome(dto.getTotalIncome());
        entry.setSeniorityFrom(BigDecimal.valueOf((dto.getGradeLevel() - 1) * 2L));
        entry.setSeniorityTo(dto.getGradeLevel() >= 10 ? null : BigDecimal.valueOf(dto.getGradeLevel() * 2L));
        return toEntryDto(scaleEntryRepository.save(entry));
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void deleteEntry(Long id, String salaryToken) {
        salaryAccessService.requireAdminGrant(salaryToken);
        scaleEntryRepository.deleteById(id);
    }

    public int gradeLevelFromSeniority(BigDecimal seniorityYears) {
        return salaryCalculator.calculateGrade(seniorityYears);
    }

    public String yearsRangeForGradePublic(int grade) {
        return salaryCalculator.yearsRangeForGrade(grade);
    }

    public ComputedSalaryGradeDto computeEmployeeGrade(SalaryScaleType type, String qualification, int gradeLevel) {
        return salaryCalculator.findEmployeeGrade(type, qualification, gradeLevel);
    }

    public ComputedSalaryGradeDto computeDoctorGrade(String qualificationCode, BigDecimal seniorityYears) {
        return salaryCalculator.computeDoctorGrade(qualificationCode, seniorityYears);
    }

    private EmployeeScaleDto buildEmployeeScaleView(SalaryScaleType type) {
        List<SalaryScaleEntry> all = scaleEntryRepository.findByScaleTypeOrderByQualificationAscGradeLevelAsc(type);
        if (all.isEmpty()) {
            return EmployeeScaleDto.builder()
                    .scaleType(type.name())
                    .title(type == SalaryScaleType.EMPLOYEE_DIRECT ? "Khối trực tiếp" : "Khối gián tiếp")
                    .baseTotalAtCoef1(BigDecimal.ZERO)
                    .baseInsuranceAtCoef1(BigDecimal.ZERO)
                    .baseProductAtCoef1(BigDecimal.ZERO)
                    .tiers(List.of())
                    .build();
        }
        Map<String, List<SalaryScaleEntry>> byQual = all.stream()
                .collect(Collectors.groupingBy(SalaryScaleEntry::getQualification, LinkedHashMap::new, Collectors.toList()));
        List<EmployeeScaleTierDto> tiers = new ArrayList<>();
        int tierIdx = 1;
        for (String qualName : QUALIFICATION_ORDER) {
            List<SalaryScaleEntry> qualEntries = byQual.get(qualName);
            if (qualEntries == null || qualEntries.isEmpty()) {
                continue;
            }
            List<EmployeeScaleGradeDto> grades = qualEntries.stream()
                    .sorted(Comparator.comparingInt(SalaryScaleEntry::getGradeLevel))
                    .map(entry -> EmployeeScaleGradeDto.builder()
                            .gradeLevel(entry.getGradeLevel())
                            .gradeLabel("BẬC " + entry.getGradeLevel())
                            .yearsRange(salaryCalculator.yearsRangeForGrade(entry.getGradeLevel()))
                            .coefficient(entry.getCoefficient())
                            .insuranceSalary(entry.getBaseInsuranceSalary())
                            .productSalary(entry.getProductSalary())
                            .totalIncome(entry.getTotalIncome())
                            .build())
                    .toList();
            tiers.add(EmployeeScaleTierDto.builder()
                    .tierGroup(tierIdx++)
                    .tierLabel(qualName)
                    .grades(grades)
                    .build());
        }
        for (Map.Entry<String, List<SalaryScaleEntry>> e : byQual.entrySet()) {
            if (QUALIFICATION_ORDER.contains(e.getKey())) {
                continue;
            }
            List<EmployeeScaleGradeDto> grades = e.getValue().stream()
                    .sorted(Comparator.comparingInt(SalaryScaleEntry::getGradeLevel))
                    .map(entry -> EmployeeScaleGradeDto.builder()
                            .gradeLevel(entry.getGradeLevel())
                            .gradeLabel("BẬC " + entry.getGradeLevel())
                            .yearsRange(salaryCalculator.yearsRangeForGrade(entry.getGradeLevel()))
                            .coefficient(entry.getCoefficient())
                            .insuranceSalary(entry.getBaseInsuranceSalary())
                            .productSalary(entry.getProductSalary())
                            .totalIncome(entry.getTotalIncome())
                            .build())
                    .toList();
            tiers.add(EmployeeScaleTierDto.builder()
                    .tierGroup(tierIdx++)
                    .tierLabel(e.getKey())
                    .grades(grades)
                    .build());
        }
        SalaryScaleEntry baseEntry = all.stream()
                .filter(e -> SalaryQualifications.LAO_DONG.equals(e.getQualification()) && e.getGradeLevel() == 1)
                .findFirst()
                .orElse(all.stream().filter(e -> e.getGradeLevel() == 1).findFirst().orElse(null));
        BigDecimal baseTotal = baseEntry != null ? baseEntry.getTotalIncome() : BigDecimal.ZERO;
        BigDecimal baseIns = baseEntry != null ? baseEntry.getBaseInsuranceSalary() : BigDecimal.ZERO;
        BigDecimal baseProd = baseEntry != null ? baseEntry.getProductSalary() : BigDecimal.ZERO;
        return EmployeeScaleDto.builder()
                .scaleType(type.name())
                .title(type == SalaryScaleType.EMPLOYEE_DIRECT ? "Khối trực tiếp" : "Khối gián tiếp")
                .baseTotalAtCoef1(baseTotal)
                .baseInsuranceAtCoef1(baseIns)
                .baseProductAtCoef1(baseProd)
                .tiers(tiers)
                .build();
    }

    private SalaryScaleEntryDto toEntryDto(SalaryScaleEntry e) {
        return SalaryScaleEntryDto.builder()
                .id(e.getId())
                .scaleType(e.getScaleType().name())
                .qualification(e.getQualification())
                .gradeLevel(e.getGradeLevel())
                .yearsRange(salaryCalculator.yearsRangeForGrade(e.getGradeLevel()))
                .coefficient(e.getCoefficient())
                .baseInsuranceSalary(e.getBaseInsuranceSalary())
                .productSalary(e.getProductSalary())
                .totalIncome(e.getTotalIncome())
                .build();
    }

    private List<DoctorScaleEntryDto> listDoctorScale() {
        return doctorEntryRepository.findAllByOrderBySortOrderAsc().stream()
                .map(e -> DoctorScaleEntryDto.builder()
                        .id(e.getId())
                        .qualificationCode(e.getQualificationCode())
                        .qualificationName(e.getQualificationName())
                        .timeLabel(e.getTimeLabel())
                        .yearsMin(e.getYearsMin())
                        .yearsMax(e.getYearsMax())
                        .totalSalary(e.getTotalSalary())
                        .build())
                .toList();
    }

    private EmployeeScaleDto emptyEmployeeScale(SalaryScaleType type) {
        return EmployeeScaleDto.builder()
                .scaleType(type.name())
                .title(type == SalaryScaleType.EMPLOYEE_DIRECT ? "Khối trực tiếp" : "Khối gián tiếp")
                .baseTotalAtCoef1(BigDecimal.ZERO)
                .baseInsuranceAtCoef1(BigDecimal.ZERO)
                .baseProductAtCoef1(BigDecimal.ZERO)
                .tiers(List.of())
                .build();
    }

    /**
     * ADMIN/HCNS 1 nhập đúng mật khẩu để xem toàn bộ; mọi vai trò khác chỉ xem đúng đối tượng lương của chính mình.
     * @return ALL | DIRECT | INDIRECT | DOCTOR | NONE
     */
    private String resolveViewerScope(String salaryToken) {
        return resolveViewerScope(salaryToken, false);
    }

    private String resolveViewerScope(String salaryToken, boolean forceSelf) {
        UserAccount current = employeeService.currentUser();
        if (!forceSelf && (current.getRole() == UserRole.ADMIN || current.getRole() == UserRole.HR)) {
            salaryAccessService.requireAdminGrant(salaryToken);
            return "ALL";
        }
        // Dùng liên kết SĐT/SSO (không chỉ user.employee) — khớp trang Chi tiết lương.
        Employee emp = employeeService.linkedEmployee(current).orElse(null);
        if (emp == null) {
            return "NONE";
        }
        EmployeeSalaryProfile profile = salaryProfileRepository.findByEmployee(emp).orElse(null);
        if (profile == null) {
            return "NONE";
        }
        if (profile.getSalaryCategory() == SalaryCategory.DOCTOR) {
            return "DOCTOR";
        }
        if (profile.getEmployeeBlock() == EmployeeSalaryBlock.INDIRECT) {
            return "INDIRECT";
        }
        if (profile.getEmployeeBlock() == EmployeeSalaryBlock.DIRECT) {
            return "DIRECT";
        }
        // Hồ sơ đã có category nhân viên nhưng chưa gắn khối → vẫn NONE
        return "NONE";
    }

    private void assertCanViewScaleType(SalaryScaleType type, String salaryToken) {
        String scope = resolveViewerScope(salaryToken);
        if ("ALL".equals(scope)) {
            return;
        }
        boolean allowed = ("DIRECT".equals(scope) && type == SalaryScaleType.EMPLOYEE_DIRECT)
                || ("INDIRECT".equals(scope) && type == SalaryScaleType.EMPLOYEE_INDIRECT);
        if (!allowed) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Bạn chỉ được xem thang bảng lương theo đối tượng của mình");
        }
    }
}
