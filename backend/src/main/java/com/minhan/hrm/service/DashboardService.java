package com.minhan.hrm.service;

import com.minhan.hrm.dto.employee.EmployeeSummaryDto;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.mapper.EmployeeMapper;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.EmployeeDocumentRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import com.minhan.hrm.repository.SalaryInfoRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository employeeWorkforceDetailsRepository;
    private final DepartmentRepository departmentRepository;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeDocumentRepository employeeDocumentRepository;
    private final SalaryInfoRepository salaryInfoRepository;

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    public Map<String, Object> stats() {
        Map<String, Object> m = new HashMap<>();
        long employees = employeeRepository.count();
        long employeeRoleUsers = userAccountRepository.countByRole(UserRole.EMPLOYEE);
        m.put("totalEmployees", employees);
        m.put("activeEmployees", employeeRepository.countByStatus(EmployeeStatus.ACTIVE));
        m.put("maternityLeave", employeeWorkforceDetailsRepository.countMaternityLeaveOfficial());
        m.put("departments", departmentRepository.count());
        m.put("employeeRoleAccounts", employeeRoleUsers);
        m.put("accountsMatchEmployees", employees == employeeRoleUsers);
        m.put("totalPdfDocuments", employeeDocumentRepository.count());
        LocalDate today = LocalDate.now();
        LocalDate horizon = today.plusDays(14);
        m.put("salaryReviewsDueSoon", salaryInfoRepository.countByNextReviewDateBetween(today, horizon));

        m.put("statusBreakdown", statusBreakdown());
        m.put("employeesByDepartment", employeesByDepartment());
        m.put("hiresByMonth", hiresLast12Months());
        return m;
    }

    private Map<String, Long> statusBreakdown() {
        long maternityLeave = employeeWorkforceDetailsRepository.countMaternityLeaveOfficial();
        long active = employeeRepository.countByStatus(EmployeeStatus.ACTIVE);
        long onLeave = employeeRepository.countByStatus(EmployeeStatus.ON_LEAVE);
        long working = Math.max(0L, active - maternityLeave) + onLeave;
        long trial = employeeRepository.countByStatus(EmployeeStatus.PROBATION)
                + employeeRepository.countByStatus(EmployeeStatus.INTERN);
        long terminated = employeeRepository.countByStatus(EmployeeStatus.TERMINATED);

        Map<String, Long> out = new LinkedHashMap<>();
        out.put("working", working);
        out.put("maternityLeave", maternityLeave);
        out.put("trial", trial);
        out.put("terminated", terminated);
        return out;
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    public List<EmployeeSummaryDto> employeesHiredInMonth(int year, int month) {
        List<Employee> employees = employeeRepository.findByHireYearAndMonth(year, month);
        return toSummaries(employees);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    public List<EmployeeSummaryDto> employeesInDepartment(Long departmentId) {
        List<Employee> employees = employeeRepository.findByDepartment_Id(
                departmentId, Sort.by("fullName").ascending());
        return toSummaries(employees);
    }

    private List<EmployeeSummaryDto> toSummaries(List<Employee> employees) {
        if (employees.isEmpty()) {
            return List.of();
        }
        Map<Long, EmployeeWorkforceDetails> workforceByEmployeeId = employeeWorkforceDetailsRepository
                .findByEmployeeIn(employees).stream()
                .collect(Collectors.toMap(w -> w.getEmployee().getId(), Function.identity()));
        return employees.stream()
                .map(emp -> EmployeeMapper.toSummary(emp, workforceByEmployeeId.get(emp.getId())))
                .toList();
    }

    private List<Map<String, Object>> employeesByDepartment() {
        return employeeRepository.countEmployeesByDepartmentRaw().stream()
                .map(row -> {
                    long count = row[2] != null ? ((Number) row[2]).longValue() : 0L;
                    long trial = row[3] != null ? ((Number) row[3]).longValue() : 0L;
                    long official = Math.max(0L, count - trial);
                    Map<String, Object> item = new HashMap<>();
                    item.put("departmentId", row[0] != null ? ((Number) row[0]).longValue() : null);
                    item.put("departmentName", row[1] != null ? row[1].toString() : "—");
                    item.put("count", count);
                    item.put("officialCount", official);
                    item.put("trialCount", trial);
                    return item;
                })
                .collect(Collectors.toList());
    }

    /** 12 tháng gần nhất (kể cả tháng không có tuyển = 0) — phục vụ biểu đồ */
    private List<Map<String, Object>> hiresLast12Months() {
        LocalDate start = LocalDate.now().withDayOfMonth(1).minusMonths(11);
        List<Object[]> raw = employeeRepository.countHiresByMonthSinceRaw(start);
        Map<String, long[]> byKey = new HashMap<>();
        for (Object[] r : raw) {
            if (r == null || r.length < 4) {
                continue;
            }
            int y = ((Number) r[0]).intValue();
            int mo = ((Number) r[1]).intValue();
            long c = ((Number) r[2]).longValue();
            long trial = r[3] != null ? ((Number) r[3]).longValue() : 0L;
            byKey.put(y + "-" + String.format("%02d", mo), new long[] { c, trial });
        }
        List<Map<String, Object>> out = new ArrayList<>();
        LocalDate cur = start;
        LocalDate end = LocalDate.now().withDayOfMonth(1);
        while (!cur.isAfter(end)) {
            String key = cur.getYear() + "-" + String.format("%02d", cur.getMonthValue());
            long[] counts = byKey.getOrDefault(key, new long[] { 0L, 0L });
            long cnt = counts[0];
            long trial = counts[1];
            long official = Math.max(0L, cnt - trial);
            Map<String, Object> row = new HashMap<>();
            row.put("year", cur.getYear());
            row.put("month", cur.getMonthValue());
            row.put("label", "T" + cur.getMonthValue() + "/" + String.valueOf(cur.getYear()).substring(2));
            row.put("count", cnt);
            row.put("officialCount", official);
            row.put("trialCount", trial);
            out.add(row);
            cur = cur.plusMonths(1);
        }
        return out;
    }
}
