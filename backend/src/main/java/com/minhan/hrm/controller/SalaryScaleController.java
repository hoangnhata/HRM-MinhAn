package com.minhan.hrm.controller;

import com.minhan.hrm.dto.salary.EmployeeScaleDto;
import com.minhan.hrm.dto.salary.SalaryScaleEntryDto;
import com.minhan.hrm.dto.salary.UpdateEmployeeScaleBaseRequest;
import com.minhan.hrm.entity.SalaryScaleType;
import com.minhan.hrm.salary.SalaryQualifications;
import com.minhan.hrm.service.SalaryScaleService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/salary-scales")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Salary Scales", description = "Thang bảng lương — mọi người xem được")
public class SalaryScaleController {

    private final SalaryScaleService salaryScaleService;

    @GetMapping
    @Operation(summary = "Toàn bộ thang bảng lương")
    public Map<String, Object> all() {
        return salaryScaleService.getAllScales();
    }

    @GetMapping("/entries")
    @Operation(summary = "Danh sách dòng thang lương (lọc khối)")
    public List<SalaryScaleEntryDto> entries(@RequestParam SalaryScaleType scaleType) {
        return salaryScaleService.listEntries(scaleType);
    }

    @GetMapping("/employee/{scaleType}")
    public EmployeeScaleDto employeeScale(@PathVariable SalaryScaleType scaleType) {
        return salaryScaleService.getEmployeeScale(scaleType);
    }

    @PutMapping("/employee/{scaleType}/base")
    @Operation(summary = "Cập nhật tổng thu nhập Bậc 1 theo trình độ (ADMIN/HR)")
    public EmployeeScaleDto updateBase(
            @PathVariable SalaryScaleType scaleType,
            @Valid @RequestBody UpdateEmployeeScaleBaseRequest req) {
        String qual = req.getQualification() != null && !req.getQualification().isBlank()
                ? req.getQualification()
                : SalaryQualifications.LAO_DONG;
        return salaryScaleService.updateEmployeeScaleBase(scaleType, req.getBaseTotalIncome(), qual);
    }

    @PutMapping("/entries/{id}")
    @Operation(summary = "Sửa một dòng thang lương")
    public SalaryScaleEntryDto updateEntry(@PathVariable Long id, @Valid @RequestBody SalaryScaleEntryDto dto) {
        return salaryScaleService.saveEntry(dto);
    }

    @PostMapping("/entries")
    @Operation(summary = "Thêm / cập nhật dòng thang lương")
    public SalaryScaleEntryDto createEntry(@Valid @RequestBody SalaryScaleEntryDto dto) {
        return salaryScaleService.saveEntry(dto);
    }

    @DeleteMapping("/entries/{id}")
    @Operation(summary = "Xóa dòng thang lương")
    public void deleteEntry(@PathVariable Long id) {
        salaryScaleService.deleteEntry(id);
    }
}
