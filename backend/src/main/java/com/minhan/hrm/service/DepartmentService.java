package com.minhan.hrm.service;

import com.minhan.hrm.dto.department.DepartmentRequest;
import com.minhan.hrm.entity.Department;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DepartmentService {

    private final DepartmentRepository departmentRepository;
    private final EmployeeRepository employeeRepository;

    @Transactional(readOnly = true)
    public List<Department> listAll() {
        return departmentRepository.findAll(Sort.by("name"));
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public Department create(DepartmentRequest req) {
        String code = allocateUniqueInternalCode();
        Department d = Department.builder()
                .code(code)
                .name(req.getName().trim())
                .description(blankToNull(req.getDescription()))
                .build();
        return departmentRepository.save(d);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public Department update(Long id, DepartmentRequest req) {
        Department d = departmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban"));
        d.setName(req.getName().trim());
        d.setDescription(blankToNull(req.getDescription()));
        return departmentRepository.save(d);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public void delete(Long id) {
        Department d = departmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban"));
        if (employeeRepository.countByDepartment_Id(id) > 0) {
            throw new ApiException(HttpStatus.CONFLICT, "Không xóa được — còn nhân viên thuộc phòng ban này.");
        }
        departmentRepository.delete(d);
    }

    /** Mã nội bộ duy nhất — không hiển thị trên giao diện quản lý. */
    private String allocateUniqueInternalCode() {
        for (int attempt = 0; attempt < 80; attempt++) {
            String c = "D" + UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase();
            if (c.length() > 32) {
                c = c.substring(0, 32);
            }
            if (!departmentRepository.existsByCode(c)) {
                return c;
            }
        }
        throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được mã phòng ban nội bộ");
    }

    private static String blankToNull(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        return s.trim();
    }
}
