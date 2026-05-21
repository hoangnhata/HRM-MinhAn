package com.minhan.hrm.service;

import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.EmployeeDocumentRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.SalaryInfoRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final EmployeeRepository employeeRepository;
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
        m.put("onLeave", employeeRepository.countByStatus(EmployeeStatus.ON_LEAVE));
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
        Map<String, Long> out = new LinkedHashMap<>();
        out.put("active", employeeRepository.countByStatus(EmployeeStatus.ACTIVE));
        out.put("onLeave", employeeRepository.countByStatus(EmployeeStatus.ON_LEAVE));
        out.put("terminated", employeeRepository.countByStatus(EmployeeStatus.TERMINATED));
        return out;
    }

    private List<Map<String, Object>> employeesByDepartment() {
        return employeeRepository.countEmployeesByDepartmentRaw().stream()
                .map(row -> {
                    Map<String, Object> item = new HashMap<>();
                    item.put("departmentName", row[0] != null ? row[0].toString() : "—");
                    item.put("count", row[1] != null ? ((Number) row[1]).longValue() : 0L);
                    return item;
                })
                .collect(Collectors.toList());
    }

    /** 12 tháng gần nhất (kể cả tháng không có tuyển = 0) — phục vụ biểu đồ */
    private List<Map<String, Object>> hiresLast12Months() {
        LocalDate start = LocalDate.now().withDayOfMonth(1).minusMonths(11);
        List<Object[]> raw = employeeRepository.countHiresByMonthSinceRaw(start);
        Map<String, Long> byKey = new HashMap<>();
        for (Object[] r : raw) {
            if (r == null || r.length < 3) {
                continue;
            }
            int y = ((Number) r[0]).intValue();
            int mo = ((Number) r[1]).intValue();
            long c = ((Number) r[2]).longValue();
            byKey.put(y + "-" + String.format("%02d", mo), c);
        }
        List<Map<String, Object>> out = new ArrayList<>();
        LocalDate cur = start;
        LocalDate end = LocalDate.now().withDayOfMonth(1);
        while (!cur.isAfter(end)) {
            String key = cur.getYear() + "-" + String.format("%02d", cur.getMonthValue());
            long cnt = byKey.getOrDefault(key, 0L);
            Map<String, Object> row = new HashMap<>();
            row.put("year", cur.getYear());
            row.put("month", cur.getMonthValue());
            row.put("label", "T" + cur.getMonthValue() + "/" + String.valueOf(cur.getYear()).substring(2));
            row.put("count", cnt);
            out.add(row);
            cur = cur.plusMonths(1);
        }
        return out;
    }
}
