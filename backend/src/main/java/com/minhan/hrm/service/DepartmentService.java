package com.minhan.hrm.service;

import com.minhan.hrm.dto.department.DepartmentRequest;
import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.DepartmentWorkUnitRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DepartmentService {

    private final DepartmentRepository departmentRepository;
    private final EmployeeRepository employeeRepository;
    private final DepartmentWorkUnitRepository workUnitRepository;
    private final EmployeeService employeeService;

    @Transactional(readOnly = true)
    public List<Department> listAll() {
        UserAccount caller = employeeService.currentUser();
        // Tài khoản quản trị/toàn viện có thể vẫn được liên kết với một hồ sơ nhân viên.
        // Không dùng khoa/phòng của hồ sơ đó để thu hẹp danh mục được phép chọn.
        // HCNS2 được xem bảng công toàn viện ở chế độ chỉ đọc nên cũng cần toàn bộ
        // danh mục khoa/phòng để lọc. Không đưa HR2 vào canViewHospitalWide vì hàm
        // đó còn được dùng để cấp quyền xem hồ sơ nhân viên chi tiết.
        if (EmployeeService.canViewHospitalWide(caller)
                || EmployeeService.isHr2Role(caller)) {
            return departmentRepository.findAll(Sort.by("name"));
        }
        if (caller != null && caller.getRole() == UserRole.HEAD_NURSING) {
            return departmentsWithNursingBlockStaff();
        }
        Long scopedDept = employeeService.resolveHeadDepartmentScope(caller);
        if (scopedDept != null) {
            Department d = departmentRepository.findById(scopedDept)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban"));
            return List.of(d);
        }
        return departmentRepository.findAll(Sort.by("name"));
    }

    /** Khoa/phòng có nhân sự khối ĐD–KTV–HS–Thư ký (phạm vi lọc của Trưởng phòng Điều dưỡng). */
    private List<Department> departmentsWithNursingBlockStaff() {
        Set<Long> ids = new LinkedHashSet<>();
        for (Employee e : employeeRepository.findAll(Sort.by("fullName"))) {
            if (e.getStatus() == EmployeeStatus.TERMINATED) {
                continue;
            }
            if (!NursingBlockClassifier.matches(e)) {
                continue;
            }
            if (e.getDepartment() != null && e.getDepartment().getId() != null) {
                ids.add(e.getDepartment().getId());
            }
        }
        if (ids.isEmpty()) {
            return List.of();
        }
        return departmentRepository.findAllById(ids).stream()
                .filter(Objects::nonNull)
                .sorted(Comparator.comparing(Department::getName, String.CASE_INSENSITIVE_ORDER))
                .toList();
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
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

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Department update(Long id, DepartmentRequest req) {
        Department d = departmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban"));
        d.setName(req.getName().trim());
        d.setDescription(blankToNull(req.getDescription()));
        return departmentRepository.save(d);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void delete(Long id) {
        Department d = departmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban"));
        if (employeeRepository.countByDepartment_Id(id) > 0) {
            throw new ApiException(HttpStatus.CONFLICT, "Không xóa được — còn nhân viên thuộc phòng ban này.");
        }
        workUnitRepository.findByDepartment_IdOrderByNameAsc(id).forEach(workUnitRepository::delete);
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
