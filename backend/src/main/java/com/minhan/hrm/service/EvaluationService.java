package com.minhan.hrm.service;

import com.minhan.hrm.dto.evaluation.EvaluationRequest;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.Evaluation;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EvaluationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class EvaluationService {

    private final EvaluationRepository evaluationRepository;
    private final EmployeeService employeeService;
    private final EmployeeRepository employeeRepository;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listForEmployee(Long employeeId) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanViewEmployee(emp);
        return evaluationRepository.findByEmployeeOrderByPeriodYearDescPeriodMonthDesc(emp).stream()
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public Map<String, Object> create(EvaluationRequest req) {
        Employee emp = employeeService.requireEmployeeEntity(req.getEmployeeId());
        UserAccount evaluator = employeeService.currentUser();
        Evaluation e = Evaluation.builder()
                .employee(emp)
                .evaluator(evaluator)
                .periodYear(req.getPeriodYear())
                .periodMonth(req.getPeriodMonth())
                .quarter(req.getQuarter())
                .score(req.getScore())
                .grade(req.getGrade())
                .comments(req.getComments())
                .build();
        e = evaluationRepository.save(e);
        return toMap(e);
    }

    private void assertCanViewEmployee(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() == UserRole.ADMIN) {
            return;
        }
        Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
        if (self == null || !self.getId().equals(target.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đánh giá");
        }
    }

    private Map<String, Object> toMap(Evaluation e) {
        return Map.of(
                "id", e.getId(),
                "employeeId", e.getEmployee().getId(),
                "periodYear", e.getPeriodYear(),
                "periodMonth", e.getPeriodMonth() != null ? e.getPeriodMonth() : 0,
                "quarter", e.getQuarter() != null ? e.getQuarter() : 0,
                "score", e.getScore(),
                "grade", e.getGrade(),
                "comments", e.getComments() != null ? e.getComments() : "",
                "evaluatorUsername", e.getEvaluator().getUsername(),
                "createdAt", e.getCreatedAt().toString());
    }
}
