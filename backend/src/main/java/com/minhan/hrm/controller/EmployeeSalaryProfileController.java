package com.minhan.hrm.controller;

import com.minhan.hrm.dto.salary.EmployeeSalaryProfileDto;
import com.minhan.hrm.dto.salary.EmployeeSalaryProfileRequest;
import com.minhan.hrm.service.EmployeeSalaryProfileService;
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
@RequestMapping("/api/v1/salary-profiles")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Salary Profiles", description = "Hồ sơ lương cá nhân")
public class EmployeeSalaryProfileController {

    private final EmployeeSalaryProfileService profileService;

    @GetMapping("/employees/{employeeId}")
    @Operation(summary = "Xem hồ sơ lương (ADMIN/HR hoặc chính NV)")
    public EmployeeSalaryProfileDto get(@PathVariable Long employeeId) {
        return profileService.getProfile(employeeId);
    }

    @PutMapping("/employees/{employeeId}")
    @ResponseStatus(HttpStatus.OK)
    @Operation(summary = "Cập nhật hồ sơ lương (ADMIN/HR)")
    public EmployeeSalaryProfileDto upsert(
            @PathVariable Long employeeId,
            @Valid @RequestBody EmployeeSalaryProfileRequest req) {
        return profileService.upsertProfile(employeeId, req);
    }

    @PostMapping("/recalculate-all")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Tính lại lương toàn bộ nhân viên có hồ sơ")
    public Map<String, Object> recalculateAll() {
        int n = profileService.recalculateAll();
        return Map.of("recalculated", n);
    }

    @GetMapping("/export")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Export bảng lương tổng hợp")
    public List<Map<String, Object>> export() {
        return profileService.exportAllProfiles();
    }
}
