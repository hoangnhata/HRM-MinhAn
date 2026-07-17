package com.minhan.hrm.controller;

import com.minhan.hrm.dto.payroll.PayrollRequest;
import com.minhan.hrm.service.PayrollService;
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
@RequestMapping("/j1-api/v1/payroll")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Payroll", description = "Bảng lương — phân quyền chặt")
public class PayrollController {

    private final PayrollService payrollService;

    @GetMapping("/employees/{employeeId}")
    @Operation(summary = "Bảng lương theo nhân viên (ADMIN hoặc chính NV)")
    public List<Map<String, Object>> forEmployee(@PathVariable Long employeeId) {
        return payrollService.listForEmployee(employeeId);
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Toàn bộ bảng lương (ADMIN)")
    public List<Map<String, Object>> all() {
        return payrollService.listAll();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Tạo / cập nhật kỳ lương")
    public Map<String, Object> upsert(@Valid @RequestBody PayrollRequest request) {
        return payrollService.upsert(request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('ADMIN')")
    public void delete(@PathVariable Long id) {
        payrollService.delete(id);
    }
}
