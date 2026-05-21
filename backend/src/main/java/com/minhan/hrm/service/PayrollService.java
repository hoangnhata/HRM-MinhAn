package com.minhan.hrm.service;

import com.minhan.hrm.dto.payroll.PayrollRequest;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.PayrollRecord;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.PayrollRecordRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PayrollService {

    private final PayrollRecordRepository payrollRecordRepository;
    private final EmployeeService employeeService;
    private final EmployeeRepository employeeRepository;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listForEmployee(Long employeeId) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanViewPayroll(emp);
        return payrollRecordRepository.findByEmployeeOrderByPeriodYearDescPeriodMonthDesc(emp).stream()
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    public List<Map<String, Object>> listAll() {
        return payrollRecordRepository.findAll().stream().map(this::toMap).collect(Collectors.toList());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public Map<String, Object> upsert(PayrollRequest req) {
        Employee emp = employeeService.requireEmployeeEntity(req.getEmployeeId());
        Optional<PayrollRecord> existingOpt = payrollRecordRepository.findByEmployeeAndPeriodYearAndPeriodMonth(
                emp, req.getPeriodYear(), req.getPeriodMonth());
        boolean wasFinalized = existingOpt.map(PayrollRecord::isFinalized).orElse(false);
        PayrollRecord rec = existingOpt.orElseGet(() -> PayrollRecord.builder()
                .employee(emp)
                .periodYear(req.getPeriodYear())
                .periodMonth(req.getPeriodMonth())
                .build());
        rec.setWorkingDays(req.getWorkingDays());
        rec.setGrossAmount(req.getGrossAmount());
        rec.setDeductionAmount(req.getDeductionAmount() != null ? req.getDeductionAmount() : BigDecimal.ZERO);
        rec.setNetAmount(req.getNetAmount());
        rec.setNote(req.getNote());
        rec.setFinalized(req.isFinalized());
        rec = payrollRecordRepository.save(rec);
        if (rec.isFinalized() && !wasFinalized) {
            notificationService.notifyPayrollFinalized(emp.getUser(), emp, rec.getPeriodYear(), rec.getPeriodMonth());
        }
        return toMap(rec);
    }

    private void assertCanViewPayroll(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() == UserRole.ADMIN) {
            return;
        }
        Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
        if (self == null || !self.getId().equals(target.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem bảng lương");
        }
    }

    private Map<String, Object> toMap(PayrollRecord r) {
        return Map.of(
                "id", r.getId(),
                "employeeId", r.getEmployee().getId(),
                "periodYear", r.getPeriodYear(),
                "periodMonth", r.getPeriodMonth(),
                "workingDays", r.getWorkingDays() != null ? r.getWorkingDays() : 0,
                "grossAmount", r.getGrossAmount(),
                "deductionAmount", r.getDeductionAmount(),
                "netAmount", r.getNetAmount(),
                "note", r.getNote() != null ? r.getNote() : "",
                "finalized", r.isFinalized());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public void delete(Long id) {
        if (!payrollRecordRepository.existsById(id)) {
            throw new ResourceNotFoundException("Không tìm thấy bảng lương");
        }
        payrollRecordRepository.deleteById(id);
    }
}
