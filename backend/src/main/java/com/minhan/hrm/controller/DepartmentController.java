package com.minhan.hrm.controller;

import com.minhan.hrm.dto.department.DepartmentRequest;
import com.minhan.hrm.dto.department.WorkUnitDto;
import com.minhan.hrm.dto.department.WorkUnitRequest;
import com.minhan.hrm.entity.Department;
import com.minhan.hrm.service.DepartmentService;
import com.minhan.hrm.service.DepartmentWorkUnitService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/j1-api/v1/departments")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Departments", description = "Danh mục phòng ban / đơn vị")
public class DepartmentController {

    private final DepartmentService departmentService;
    private final DepartmentWorkUnitService workUnitService;

    @GetMapping
    @Operation(summary = "Danh sách phòng ban (sắp xếp theo tên)")
    public List<Department> list() {
        return departmentService.listAll();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Tạo phòng ban")
    public Department create(@Valid @RequestBody DepartmentRequest request) {
        return departmentService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Cập nhật phòng ban")
    public Department update(@PathVariable Long id, @Valid @RequestBody DepartmentRequest request) {
        return departmentService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Xóa phòng ban (không cho phép nếu còn nhân viên)")
    public void delete(@PathVariable Long id) {
        departmentService.delete(id);
    }

    @GetMapping("/{id}/work-units")
    @Operation(summary = "Danh sách bộ phận thuộc phòng ban")
    public List<WorkUnitDto> listWorkUnits(@PathVariable Long id) {
        return workUnitService.listByDepartment(id);
    }

    @GetMapping("/work-units")
    @Operation(summary = "Danh sách tất cả bộ phận (theo phòng ban)")
    public List<WorkUnitDto> listAllWorkUnits() {
        return workUnitService.listAll();
    }

    @PostMapping("/{id}/work-units")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Thêm bộ phận vào phòng ban")
    public WorkUnitDto createWorkUnit(@PathVariable Long id, @Valid @RequestBody WorkUnitRequest request) {
        return workUnitService.create(id, request);
    }

    @PutMapping("/{id}/work-units/{workUnitId}")
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Sửa bộ phận")
    public WorkUnitDto updateWorkUnit(
            @PathVariable Long id,
            @PathVariable Long workUnitId,
            @Valid @RequestBody WorkUnitRequest request) {
        return workUnitService.update(id, workUnitId, request);
    }

    @DeleteMapping("/{id}/work-units/{workUnitId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Operation(summary = "Xóa bộ phận")
    public void deleteWorkUnit(@PathVariable Long id, @PathVariable Long workUnitId) {
        workUnitService.delete(id, workUnitId);
    }
}
