package com.minhan.hrm.service;

import com.minhan.hrm.dto.department.WorkUnitDto;
import com.minhan.hrm.dto.department.WorkUnitRequest;
import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.DepartmentWorkUnit;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.DepartmentWorkUnitRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class DepartmentWorkUnitService {

    private final DepartmentRepository departmentRepository;
    private final DepartmentWorkUnitRepository workUnitRepository;

    @Transactional(readOnly = true)
    public List<WorkUnitDto> listByDepartment(Long departmentId) {
        requireDepartment(departmentId);
        return workUnitRepository.findByDepartment_IdOrderByNameAsc(departmentId).stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<WorkUnitDto> listAll() {
        return workUnitRepository.findAll().stream()
                .sorted((a, b) -> {
                    int byDept = a.getDepartment().getName().compareToIgnoreCase(b.getDepartment().getName());
                    if (byDept != 0) {
                        return byDept;
                    }
                    return a.getName().compareToIgnoreCase(b.getName());
                })
                .map(this::toDto)
                .toList();
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public WorkUnitDto create(Long departmentId, WorkUnitRequest req) {
        Department dept = requireDepartment(departmentId);
        String name = req.getName().trim();
        if (workUnitRepository.existsByDepartment_IdAndNameIgnoreCase(departmentId, name)) {
            throw new ApiException(HttpStatus.CONFLICT, "Bộ phận \"" + name + "\" đã có trong phòng ban này.");
        }
        DepartmentWorkUnit unit = DepartmentWorkUnit.builder()
                .department(dept)
                .name(name)
                .description(blankToNull(req.getDescription()))
                .build();
        return toDto(workUnitRepository.save(unit));
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public WorkUnitDto update(Long departmentId, Long workUnitId, WorkUnitRequest req) {
        DepartmentWorkUnit unit = requireWorkUnit(departmentId, workUnitId);
        String name = req.getName().trim();
        workUnitRepository.findFirstByDepartment_IdAndNameIgnoreCaseOrderByIdAsc(departmentId, name)
                .ifPresent(other -> {
                    if (!other.getId().equals(workUnitId)) {
                        throw new ApiException(HttpStatus.CONFLICT, "Bộ phận \"" + name + "\" đã có trong phòng ban này.");
                    }
                });
        unit.setName(name);
        unit.setDescription(blankToNull(req.getDescription()));
        return toDto(workUnitRepository.save(unit));
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void delete(Long departmentId, Long workUnitId) {
        DepartmentWorkUnit unit = requireWorkUnit(departmentId, workUnitId);
        workUnitRepository.delete(unit);
    }

    /** Tìm hoặc tạo bộ phận khi import Excel — không yêu cầu ADMIN. */
    @Transactional
    public DepartmentWorkUnit findOrCreate(Department department, String rawName) {
        if (department == null || rawName == null || rawName.isBlank()) {
            return null;
        }
        String name = rawName.trim();
        return workUnitRepository
                .findFirstByDepartment_IdAndNameIgnoreCaseOrderByIdAsc(department.getId(), name)
                .orElseGet(() -> workUnitRepository.save(DepartmentWorkUnit.builder()
                        .department(department)
                        .name(name)
                        .build()));
    }

    private Department requireDepartment(Long id) {
        return departmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban"));
    }

    private DepartmentWorkUnit requireWorkUnit(Long departmentId, Long workUnitId) {
        DepartmentWorkUnit unit = workUnitRepository.findById(workUnitId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bộ phận"));
        if (!unit.getDepartment().getId().equals(departmentId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Bộ phận không thuộc phòng ban này.");
        }
        return unit;
    }

    private WorkUnitDto toDto(DepartmentWorkUnit u) {
        return WorkUnitDto.builder()
                .id(u.getId())
                .departmentId(u.getDepartment().getId())
                .departmentName(u.getDepartment().getName())
                .name(u.getName())
                .description(u.getDescription())
                .createdAt(u.getCreatedAt())
                .updatedAt(u.getUpdatedAt())
                .build();
    }

    private static String blankToNull(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        return s.trim();
    }
}
