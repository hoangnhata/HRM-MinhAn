package com.minhan.hrm.controller;

import com.minhan.hrm.dto.evaluation.EvaluationRequest;
import com.minhan.hrm.service.EvaluationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/evaluations")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Evaluations", description = "Đánh giá nhân viên")
public class EvaluationController {

    private final EvaluationService evaluationService;

    @GetMapping("/employees/{employeeId}")
    @Operation(summary = "Lịch sử đánh giá (ADMIN hoặc chính NV)")
    public List<Map<String, Object>> list(@PathVariable Long employeeId) {
        return evaluationService.listForEmployee(employeeId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Tạo bản đánh giá")
    public Map<String, Object> create(@Valid @RequestBody EvaluationRequest request) {
        return evaluationService.create(request);
    }
}
