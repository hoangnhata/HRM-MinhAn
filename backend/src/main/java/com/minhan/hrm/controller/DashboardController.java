package com.minhan.hrm.controller;

import com.minhan.hrm.dto.employee.EmployeeSummaryDto;
import com.minhan.hrm.service.DashboardService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/dashboard")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Dashboard", description = "Thống kê quản trị")
public class DashboardController {

    private final DashboardService dashboardService;

    @GetMapping("/stats")
    @Operation(summary = "Thống kê nhanh (ADMIN)")
    public Map<String, Object> stats() {
        return dashboardService.stats();
    }

    @GetMapping("/hires/{year}/{month}/employees")
    @Operation(summary = "Danh sách nhân viên nhận việc trong tháng (ADMIN)")
    public List<EmployeeSummaryDto> hiresInMonth(@PathVariable int year, @PathVariable int month) {
        return dashboardService.employeesHiredInMonth(year, month);
    }

    @GetMapping("/departments/{departmentId}/employees")
    @Operation(summary = "Danh sách nhân viên theo phòng ban (ADMIN)")
    public List<EmployeeSummaryDto> employeesByDepartment(@PathVariable Long departmentId) {
        return dashboardService.employeesInDepartment(departmentId);
    }
}
