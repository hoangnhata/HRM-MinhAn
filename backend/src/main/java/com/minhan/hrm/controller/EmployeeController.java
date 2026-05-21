package com.minhan.hrm.controller;

import com.minhan.hrm.dto.employee.EmployeeCreateRequest;
import com.minhan.hrm.dto.employee.EmployeeDetailDto;
import com.minhan.hrm.dto.employee.EmployeeSummaryDto;
import com.minhan.hrm.dto.employee.EmployeeUpdateRequest;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.service.EmployeeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/employees")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Employees", description = "Quản lý nhân viên")
public class EmployeeController {

    private final EmployeeService employeeService;

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Danh sách nhân viên (phân trang, lọc theo tên/mã/username, phòng ban, trạng thái)")
    public Page<EmployeeSummaryDto> list(
            @PageableDefault(size = 20) Pageable pageable,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) EmployeeStatus status) {
        return employeeService.list(pageable, q, departmentId, status);
    }

    @GetMapping("/me")
    @Operation(summary = "Hồ sơ nhân viên của user đang đăng nhập")
    public EmployeeDetailDto me() {
        return employeeService.getMe();
    }

    @GetMapping("/evaluation-roster")
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Operation(summary = "Danh sách NV để chấm điểm theo tháng (toàn viện, NV đang ACTIVE)")
    public List<EmployeeSummaryDto> evaluationRoster() {
        return employeeService.listEvaluationRoster();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Chi tiết nhân viên (RBAC)")
    public EmployeeDetailDto get(@PathVariable Long id) {
        return employeeService.getById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Tạo tài khoản + hồ sơ nhân viên")
    public EmployeeDetailDto create(@Valid @RequestBody EmployeeCreateRequest request) {
        return employeeService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Cập nhật hồ sơ, tài khoản và lương")
    public EmployeeDetailDto update(@PathVariable Long id, @Valid @RequestBody EmployeeUpdateRequest request) {
        return employeeService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Vô hiệu hóa nhân viên (ADMIN)")
    public void delete(@PathVariable Long id) {
        employeeService.delete(id);
    }
}
