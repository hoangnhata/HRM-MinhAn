package com.minhan.hrm.controller;

import com.minhan.hrm.dto.salary.EmployeeSalaryProfileDto;
import com.minhan.hrm.dto.salary.EmployeeSalaryProfileRequest;
import com.minhan.hrm.service.EmployeeSalaryProfileService;
import com.minhan.hrm.service.SalaryAccessService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/j1-api/v1/salary-profiles")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Salary Profiles", description = "Hồ sơ lương cá nhân")
public class EmployeeSalaryProfileController {

    private final EmployeeSalaryProfileService profileService;
    private final SalaryAccessService salaryAccessService;
    private final com.minhan.hrm.service.SalaryGradeReviewService gradeReviewService;

    @PostMapping("/unlock")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "ADMIN/HCNS 1 mở khóa phần lương bằng mật khẩu riêng")
    public SalaryAccessService.UnlockResult unlock(@RequestBody Map<String, String> body) {
        return salaryAccessService.unlock(body.get("password"));
    }

    @GetMapping("/employees/{employeeId}")
    @Operation(summary = "Xem hồ sơ lương (ADMIN/HR hoặc chính NV)")
    public EmployeeSalaryProfileDto get(
            @PathVariable Long employeeId,
            @RequestHeader(value = "X-Salary-Access-Token", required = false) String salaryToken) {
        return profileService.getProfile(employeeId, salaryToken);
    }

    @PutMapping("/employees/{employeeId}")
    @ResponseStatus(HttpStatus.OK)
    @Operation(summary = "Cập nhật hồ sơ lương (ADMIN/HR)")
    public EmployeeSalaryProfileDto upsert(
            @PathVariable Long employeeId,
            @RequestHeader(value = "X-Salary-Access-Token", required = false) String salaryToken,
            @Valid @RequestBody EmployeeSalaryProfileRequest req) {
        return profileService.upsertProfile(employeeId, req, salaryToken);
    }

    @PostMapping("/recalculate-all")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Tính lại lương toàn bộ nhân viên có hồ sơ")
    public Map<String, Object> recalculateAll(
            @RequestHeader(value = "X-Salary-Access-Token", required = false) String salaryToken) {
        int n = profileService.recalculateAll(salaryToken);
        return Map.of("recalculated", n);
    }

    @GetMapping("/export")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Export bảng lương tổng hợp")
    public List<Map<String, Object>> export(
            @RequestHeader(value = "X-Salary-Access-Token", required = false) String salaryToken) {
        return profileService.exportAllProfiles(salaryToken);
    }

    @GetMapping("/grade-reviews")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Danh sách nhân viên nâng bậc lương theo tháng")
    public Map<String, Object> gradeReviews(
            @RequestParam int year,
            @RequestParam int month,
            @RequestHeader(value = "X-Salary-Access-Token", required = false) String salaryToken) {
        return gradeReviewService.list(year, month, salaryToken);
    }

    @GetMapping("/grade-reviews/excel")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Xuất Excel danh sách nâng bậc lương theo tháng")
    public ResponseEntity<byte[]> exportGradeReviews(
            @RequestParam int year,
            @RequestParam int month,
            @RequestHeader(value = "X-Salary-Access-Token", required = false) String salaryToken) {
        byte[] body = gradeReviewService.exportExcel(year, month, salaryToken);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=salary-grade-review-" + year + "-" + String.format("%02d", month) + ".xlsx")
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(body);
    }
}
