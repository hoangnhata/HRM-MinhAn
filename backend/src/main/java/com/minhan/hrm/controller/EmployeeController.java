package com.minhan.hrm.controller;

import com.minhan.hrm.dto.employee.ConfirmOfficialRequest;
import com.minhan.hrm.dto.employee.EmployeeCreateRequest;
import com.minhan.hrm.dto.employee.EmployeeDetailDto;
import com.minhan.hrm.dto.employee.EmployeeSummaryDto;
import com.minhan.hrm.dto.employee.EmployeeUpdateRequest;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeStatusGroup;
import com.minhan.hrm.entity.OfficialWorkFilter;
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
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Danh sách nhân viên (phân trang, lọc theo tên/mã/username, phòng ban, trạng thái hoặc nhóm tab)")
    public Page<EmployeeSummaryDto> list(
            @PageableDefault(size = 20) Pageable pageable,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) EmployeeStatus status,
            @RequestParam(required = false) EmployeeStatusGroup statusGroup,
            @RequestParam(required = false) OfficialWorkFilter officialWorkFilter) {
        return employeeService.list(pageable, q, departmentId, status, statusGroup, officialWorkFilter);
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
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Tạo tài khoản + hồ sơ nhân viên")
    public EmployeeDetailDto create(@Valid @RequestBody EmployeeCreateRequest request) {
        return employeeService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cập nhật hồ sơ, tài khoản và lương")
    public EmployeeDetailDto update(@PathVariable Long id, @Valid @RequestBody EmployeeUpdateRequest request) {
        return employeeService.update(id, request);
    }

    @PostMapping("/{id}/confirm-official")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Chuyển nhân viên thử việc / thực tập lên chính thức")
    public EmployeeDetailDto confirmOfficial(
            @PathVariable Long id,
            @RequestBody(required = false) ConfirmOfficialRequest request) {
        return employeeService.confirmOfficial(id, request != null ? request.getOfficialDate() : null);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Nghỉ việc — vô hiệu hóa tài khoản")
    public void delete(@PathVariable Long id) {
        employeeService.delete(id);
    }

    @DeleteMapping("/{id}/permanent")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Xóa vĩnh viễn hồ sơ nhân viên đã nghỉ việc")
    public void permanentlyDelete(@PathVariable Long id) {
        employeeService.permanentlyDelete(id);
    }
}
