package com.minhan.hrm.service;

import com.minhan.hrm.dto.employee.EmployeeSummaryDto;
import com.minhan.hrm.entity.AttendanceRequestStatus;
import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.entity.MainDutyAuthorizationStatus;
import com.minhan.hrm.entity.ProbationConversionStatus;
import com.minhan.hrm.mapper.EmployeeMapper;
import com.minhan.hrm.repository.AttendanceWorkRequestRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import com.minhan.hrm.repository.MainDutyAuthorizationRequestRepository;
import com.minhan.hrm.repository.ProbationConversionRequestRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class NursingDashboardService {

    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository employeeWorkforceDetailsRepository;
    private final AttendanceWorkRequestRepository attendanceWorkRequestRepository;
    private final ProbationConversionRequestRepository probationConversionRequestRepository;
    private final MainDutyAuthorizationRequestRepository mainDutyAuthorizationRequestRepository;

    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Transactional(readOnly = true)
    public Map<String, Object> stats() {
        List<Employee> block = nursingBlockEmployees();

        Map<String, Object> m = new HashMap<>();
        m.put("totalInBlock", block.size());

        Map<String, Long> bySubGroup = new LinkedHashMap<>();
        for (NursingBlockClassifier.SubGroup g : NursingBlockClassifier.SubGroup.values()) {
            bySubGroup.put(NursingBlockClassifier.subGroupLabel(g), 0L);
        }
        long official = 0;
        long trial = 0;
        long mainDutyAuthorized = 0;
        /** key = departmentId (0 nếu null), value = [total, official, trial] + name stored separately */
        Map<Long, long[]> byDeptCounts = new LinkedHashMap<>();
        Map<Long, String> byDeptNames = new LinkedHashMap<>();

        for (Employee e : block) {
            NursingBlockClassifier.SubGroup g = NursingBlockClassifier.subGroup(e);
            String label = NursingBlockClassifier.subGroupLabel(g);
            bySubGroup.merge(label, 1L, Long::sum);

            if (e.getStatus() == EmployeeStatus.PROBATION || e.getStatus() == EmployeeStatus.INTERN) {
                trial++;
            } else if (e.getStatus() == EmployeeStatus.ACTIVE || e.getStatus() == EmployeeStatus.ON_LEAVE) {
                official++;
            }
            if (e.isMainDutyAuthorized()) {
                mainDutyAuthorized++;
            }
            Long deptId = e.getDepartment() != null ? e.getDepartment().getId() : 0L;
            String deptName = e.getDepartment() != null ? e.getDepartment().getName() : "—";
            byDeptNames.putIfAbsent(deptId, deptName);
            long[] counts = byDeptCounts.computeIfAbsent(deptId, k -> new long[3]);
            counts[0]++;
            if (e.getStatus() == EmployeeStatus.PROBATION || e.getStatus() == EmployeeStatus.INTERN) {
                counts[2]++;
            } else {
                counts[1]++;
            }
        }

        m.put("bySubGroup", bySubGroup.entrySet().stream()
                .map(e -> Map.<String, Object>of("label", e.getKey(), "count", e.getValue()))
                .toList());

        List<Map<String, Object>> deptRows = new ArrayList<>();
        byDeptCounts.entrySet().stream()
                .sorted((a, b) -> String.CASE_INSENSITIVE_ORDER.compare(
                        byDeptNames.getOrDefault(a.getKey(), ""),
                        byDeptNames.getOrDefault(b.getKey(), "")))
                .forEach(e -> {
                    Map<String, Object> row = new LinkedHashMap<>();
                    Long id = e.getKey();
                    row.put("departmentId", id != null && id > 0 ? id : null);
                    row.put("departmentName", byDeptNames.getOrDefault(id, "—"));
                    row.put("count", e.getValue()[0]);
                    row.put("officialCount", e.getValue()[1]);
                    row.put("trialCount", e.getValue()[2]);
                    deptRows.add(row);
                });
        m.put("byDepartment", deptRows);

        Map<String, Long> statusBreakdown = new LinkedHashMap<>();
        statusBreakdown.put("official", official);
        statusBreakdown.put("trial", trial);
        statusBreakdown.put("mainDutyAuthorized", mainDutyAuthorized);
        m.put("statusBreakdown", statusBreakdown);
        m.put("mainDutyAuthorized", mainDutyAuthorized);
        m.put("officialCount", official);
        m.put("trialCount", trial);

        long pendingDeployments = attendanceWorkRequestRepository
                .findByStatusInOrderByCreatedAtAsc(EnumSet.of(AttendanceRequestStatus.PENDING_NURSING_HEAD))
                .stream()
                .filter(r -> r.getRequestType() == AttendanceRequestType.DEPLOYMENT)
                .count();
        long pendingProbation = probationConversionRequestRepository
                .findPendingWithDetails(ProbationConversionStatus.PENDING_NURSING_HEAD)
                .size();
        long pendingMainDuty = mainDutyAuthorizationRequestRepository
                .findPendingWithDetails(MainDutyAuthorizationStatus.PENDING_NURSING_HEAD)
                .size();

        m.put("pendingDeployments", pendingDeployments);
        m.put("pendingProbation", pendingProbation);
        m.put("pendingMainDuty", pendingMainDuty);
        m.put("pendingTotal", pendingDeployments + pendingProbation + pendingMainDuty);

        m.put("departmentsCovered", deptRows.size());
        return m;
    }

    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    @Transactional(readOnly = true)
    public List<EmployeeSummaryDto> employeesInDepartment(Long departmentId) {
        List<Employee> employees = nursingBlockEmployees().stream()
                .filter(e -> {
                    if (departmentId == null) {
                        return e.getDepartment() == null;
                    }
                    return e.getDepartment() != null && departmentId.equals(e.getDepartment().getId());
                })
                .sorted((a, b) -> String.CASE_INSENSITIVE_ORDER.compare(
                        a.getFullName() != null ? a.getFullName() : "",
                        b.getFullName() != null ? b.getFullName() : ""))
                .toList();
        return toSummaries(employees);
    }

    private List<Employee> nursingBlockEmployees() {
        return employeeRepository.findAll(Sort.by("fullName").ascending()).stream()
                .filter(NursingBlockClassifier::matches)
                .filter(e -> e.getStatus() != EmployeeStatus.TERMINATED)
                .toList();
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
}
