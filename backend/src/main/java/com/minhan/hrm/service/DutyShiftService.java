package com.minhan.hrm.service;

import com.minhan.hrm.dto.salary.ComputedSalaryGradeDto;
import com.minhan.hrm.duty.DutyShiftCalculator;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.DutyShiftEntryRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeSalaryProfileRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import com.minhan.hrm.repository.SalaryInfoRepository;
import com.minhan.hrm.salary.SalaryAmounts;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

@Service
@RequiredArgsConstructor
public class DutyShiftService {

    private final DutyShiftEntryRepository dutyShiftEntryRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeService employeeService;
    private final EmployeeSalaryProfileRepository salaryProfileRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;
    private final SalaryInfoRepository salaryInfoRepository;
    private final SalaryCalculatorService salaryCalculatorService;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listShiftTypes() {
        List<Map<String, Object>> list = new ArrayList<>();
        for (DutyShiftType type : DutyShiftType.values()) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("code", type.getCode());
            m.put("label", type.getLabel());
            m.put("grantsWorkUnits", DutyShiftCalculator.typesWithWorkUnits().contains(type));
            m.put("roleTiers", DutyShiftCalculator.tiersForShiftType(type).stream().map(this::tierView).toList());
            list.add(m);
        }
        return list;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> preview(Long employeeId, LocalDate workDate, String shiftTypeCode, String roleTierCode) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanView(emp);
        DutyShiftType type = DutyShiftType.fromCode(shiftTypeCode);
        DutyRoleTier tier = resolveRoleTier(emp, type, roleTierCode);
        DutyShiftCalculator.CalculationResult calc = calculateForEmployee(emp, type, tier);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("shiftTypeCode", type.getCode());
        m.put("shiftTypeLabel", type.getLabel());
        m.put("roleTier", tier.getCode());
        m.put("roleTierLabel", tier.getLabel());
        m.put("bonusAmount", calc.bonusAmount());
        m.put("workUnits", calc.workUnits());
        m.put("postDutyPay", calc.postDutyPay());
        m.put("suggestedRoleTier", detectRoleTier(emp, type).getCode());
        m.put("monthlyTotalSalary", resolveMonthlySalary(emp));
        return m;
    }

    @Transactional(readOnly = true)
    public List<DutyShiftEntry> findEntriesForEmployee(Long employeeId, LocalDate from, LocalDate to) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        return dutyShiftEntryRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listForEmployee(Long employeeId, LocalDate from, LocalDate to) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanView(emp);
        return dutyShiftEntryRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to)
                .stream()
                .map(e -> toMap(emp, e))
                .toList();
    }

    @Transactional(readOnly = true)
    public Map<String, Object> monthTotals(Long employeeId, LocalDate from, LocalDate to) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanView(emp);
        return rollup(emp, dutyShiftEntryRepository.findByEmployeeAndWorkDateBetweenOrderByWorkDateAsc(emp, from, to));
    }

    @Transactional
    public Map<String, Object> upsert(
            Long employeeId, LocalDate workDate, String shiftTypeCode, String roleTierCode, String note) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanManage(emp);
        DutyShiftType type = DutyShiftType.fromCode(shiftTypeCode);
        DutyRoleTier tier = resolveRoleTier(emp, type, roleTierCode);
        DutyShiftCalculator.CalculationResult calc = calculateForEmployee(emp, type, tier);

        UserAccount current = employeeService.currentUser();
        DutyShiftEntry entry = dutyShiftEntryRepository.findByEmployeeAndWorkDate(emp, workDate)
                .orElseGet(() -> DutyShiftEntry.builder().employee(emp).workDate(workDate).build());
        entry.setShiftTypeCode(type.getCode());
        entry.setRoleTier(tier.getCode());
        entry.setBonusAmount(calc.bonusAmount());
        entry.setWorkUnits(calc.workUnits());
        entry.setPostDutyPay(calc.postDutyPay());
        entry.setNote(note != null ? note.trim() : null);
        entry.setEnteredBy(current);
        DutyShiftEntry saved = dutyShiftEntryRepository.save(entry);
        return toMap(emp, saved);
    }

    @Transactional
    public void delete(Long employeeId, LocalDate workDate) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanManage(emp);
        dutyShiftEntryRepository.findByEmployeeAndWorkDate(emp, workDate)
                .ifPresent(dutyShiftEntryRepository::delete);
    }

    /** Chi tiết từng ca trực (cho báo cáo Excel) — không kiểm tra quyền, dùng nội bộ. */
    public List<Map<String, Object>> reportEntries(Employee emp, List<DutyShiftEntry> entries) {
        return entries.stream().map(e -> toMap(emp, e)).toList();
    }

    public Map<String, Object> rollup(Employee emp, List<DutyShiftEntry> entries) {
        BigDecimal bonusTotal = BigDecimal.ZERO;
        BigDecimal postDutyPayTotal = BigDecimal.ZERO;
        BigDecimal workUnitsTotal = BigDecimal.ZERO;
        for (DutyShiftEntry e : entries) {
            DutyShiftCalculator.CalculationResult calc = computeEntryAmounts(emp, e);
            bonusTotal = bonusTotal.add(calc.bonusAmount());
            postDutyPayTotal = postDutyPayTotal.add(calc.postDutyPay());
            workUnitsTotal = workUnitsTotal.add(calc.workUnits());
        }
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("dutyBonusTotal", bonusTotal);
        m.put("dutyPostPayTotal", postDutyPayTotal);
        m.put("dutyWorkUnitsTotal", workUnitsTotal);
        m.put("dutyShiftCount", entries.size());
        return m;
    }

    public DutyRoleTier detectRoleTier(Employee emp, DutyShiftType type) {
        EmployeeSalaryProfile profile = salaryProfileRepository.findByEmployee(emp).orElse(null);
        if (profile != null && profile.getSalaryCategory() == SalaryCategory.DOCTOR) {
            return switch (type) {
                case TC1 -> DutyRoleTier.BS;
                case TCC -> DutyRoleTier.BS_DA_KHOA;
                default -> DutyRoleTier.BS_NSN_XQ_SA;
            };
        }

        String pos = normalize(emp.getPosition() != null ? emp.getPosition().getTitle() : "");
        String specialty = workforceDetailsRepository.findById(emp.getId())
                .map(w -> normalize(w.getSpecialty()))
                .orElse("");

        if (containsAny(pos, "thu ngan", "thu ngân", "duoc", "dược")) {
            return DutyRoleTier.THU_NGAN_DUOC;
        }
        if (containsAny(pos, "dieu duong", "điều dưỡng", "ddt", "y ta")) {
            return type == DutyShiftType.TCC ? DutyRoleTier.DD_CAP_CUU : DutyRoleTier.DIEU_DUONG;
        }
        if (containsAny(specialty, "noi nhi", "nội nhi", "nhi", "coc 1", "cọc 1")) {
            return DutyRoleTier.COC1_NOI_NHI;
        }
        if (type == DutyShiftType.TC1) {
            return DutyRoleTier.DIEU_DUONG;
        }
        if (type == DutyShiftType.TCC) {
            return DutyRoleTier.DD_CAP_CUU;
        }
        return DutyRoleTier.NV_TAI_KHOA;
    }

    private DutyRoleTier resolveRoleTier(Employee emp, DutyShiftType type, String roleTierCode) {
        if (roleTierCode == null || roleTierCode.isBlank()) {
            return detectRoleTier(emp, type);
        }
        DutyRoleTier tier = DutyRoleTier.fromCode(roleTierCode);
        if (!DutyShiftCalculator.tiersForShiftType(type).contains(tier) && type != DutyShiftType.TK) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Vị trí không áp dụng cho loại ca trực này");
        }
        return tier;
    }

    private DutyShiftCalculator.CalculationResult calculateForEmployee(
            Employee emp, DutyShiftType type, DutyRoleTier tier) {
        return DutyShiftCalculator.calculate(type, tier, resolveMonthlySalary(emp));
    }

    private DutyShiftCalculator.CalculationResult computeEntryAmounts(Employee emp, DutyShiftEntry e) {
        DutyShiftType type = DutyShiftType.fromCode(e.getShiftTypeCode());
        DutyRoleTier tier = DutyRoleTier.fromCode(e.getRoleTier());
        return calculateForEmployee(emp, type, tier);
    }

    private BigDecimal resolveMonthlySalary(Employee emp) {
        EmployeeSalaryProfile profile = salaryProfileRepository.findByEmployee(emp).orElse(null);
        if (profile != null && profile.getSalaryCategory() != null) {
            ComputedSalaryGradeDto grade = salaryCalculatorService.computeForProfile(emp, profile);
            BigDecimal insurance = grade.getInsuranceSalary() != null ? grade.getInsuranceSalary() : BigDecimal.ZERO;
            BigDecimal product = grade.getProductSalary() != null ? grade.getProductSalary() : BigDecimal.ZERO;
            if (SalaryAmounts.isPlausibleSalary(profile.getImportedInsuranceSalary())) {
                insurance = profile.getImportedInsuranceSalary();
            }
            if (SalaryAmounts.isPlausibleSalary(profile.getImportedProductSalary())) {
                product = profile.getImportedProductSalary();
            }
            BigDecimal attraction = profile.getProfessionalAttractionSalary() != null
                    ? profile.getProfessionalAttractionSalary() : BigDecimal.ZERO;
            BigDecimal total = salaryCalculatorService.calculateFinalSalary(insurance, product, attraction);
            if (total.compareTo(BigDecimal.ZERO) > 0) {
                return total;
            }
            if (grade.getScaleSalary() != null && grade.getScaleSalary().compareTo(BigDecimal.ZERO) > 0) {
                return grade.getScaleSalary().add(attraction);
            }
        }
        return salaryInfoRepository.findByEmployee(emp)
                .map(s -> {
                    BigDecimal base = s.getBaseSalary() != null ? s.getBaseSalary() : BigDecimal.ZERO;
                    BigDecimal allowance = s.getAllowance() != null ? s.getAllowance() : BigDecimal.ZERO;
                    return base.add(allowance);
                })
                .filter(t -> t.compareTo(BigDecimal.ZERO) > 0)
                .orElse(BigDecimal.ZERO);
    }

    private Map<String, Object> toMap(Employee emp, DutyShiftEntry e) {
        DutyShiftCalculator.CalculationResult calc = computeEntryAmounts(emp, e);
        DutyShiftType type = DutyShiftType.fromCode(e.getShiftTypeCode());
        DutyRoleTier tier = DutyRoleTier.fromCode(e.getRoleTier());
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", e.getId());
        m.put("workDate", e.getWorkDate().toString());
        m.put("shiftTypeCode", type.getCode());
        m.put("shiftTypeLabel", type.getLabel());
        m.put("roleTier", tier.getCode());
        m.put("roleTierLabel", tier.getLabel());
        m.put("bonusAmount", calc.bonusAmount());
        m.put("workUnits", calc.workUnits());
        m.put("postDutyPay", calc.postDutyPay());
        m.put("note", e.getNote() != null ? e.getNote() : "");
        return m;
    }

    private Map<String, Object> tierView(DutyRoleTier tier) {
        return Map.of("code", tier.getCode(), "label", tier.getLabel());
    }

    private void assertCanView(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() == UserRole.ADMIN || current.getRole() == UserRole.HR) {
            return;
        }
        Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
        if (self != null && self.getId().equals(target.getId())) {
            return;
        }
        if (current.getRole() == UserRole.HEAD_DEPARTMENT || current.getRole() == UserRole.HEAD_NURSING) {
            return;
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem ca trực");
    }

    private void assertCanManage(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() == UserRole.ADMIN || current.getRole() == UserRole.HR) {
            return;
        }
        Employee self = employeeRepository.findByUser(current)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản chưa gắn hồ sơ nhân viên"));
        if (current.getRole() != UserRole.HEAD_DEPARTMENT && current.getRole() != UserRole.HEAD_NURSING) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ trưởng phòng/HR/ADMIN được nhập ca trực");
        }
        if (!self.getDepartment().getId().equals(target.getDepartment().getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ nhập ca trực cho nhân viên cùng khoa/phòng");
        }
    }

    private static String normalize(String s) {
        return s != null ? s.toLowerCase(Locale.ROOT) : "";
    }

    private static boolean containsAny(String haystack, String... needles) {
        for (String n : needles) {
            if (haystack.contains(n)) {
                return true;
            }
        }
        return false;
    }
}
