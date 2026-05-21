package com.minhan.hrm.service;

import com.minhan.hrm.dto.employee.*;
import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.mapper.EmployeeMapper;
import com.minhan.hrm.mapper.WorkforceProfileMapper;
import com.minhan.hrm.repository.EmployeeSpecifications;
import com.minhan.hrm.repository.*;
import com.minhan.hrm.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class EmployeeService {

    private static final Set<UserRole> CREATABLE_ROLES = EnumSet.of(
            UserRole.EMPLOYEE, UserRole.HR, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_NURSING);

    private final EmployeeRepository employeeRepository;
    private final UserAccountRepository userAccountRepository;
    private final DepartmentRepository departmentRepository;
    private final PositionRepository positionRepository;
    private final ContractRepository contractRepository;
    private final SalaryInfoRepository salaryInfoRepository;
    private final EmployeeWorkforceDetailsRepository employeeWorkforceDetailsRepository;
    private final PasswordEncoder passwordEncoder;

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    public Page<EmployeeSummaryDto> list(Pageable pageable, String q, Long departmentId, EmployeeStatus status) {
        Specification<Employee> spec = EmployeeSpecifications.withFilters(q, departmentId, status);
        return employeeRepository.findAll(spec, pageable).map(EmployeeMapper::toSummary);
    }

    @Transactional(readOnly = true)
    public EmployeeDetailDto getMe() {
        String username = SecurityUtils.currentUsername();
        Employee e = employeeRepository.findByUserUsername(username)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "Tài khoản không gắn hồ sơ nhân viên"));
        return loadDetail(e);
    }

    @Transactional(readOnly = true)
    public EmployeeDetailDto getById(Long id) {
        Employee e = employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        assertCanAccessEmployee(e);
        return loadDetail(e);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public EmployeeDetailDto create(EmployeeCreateRequest req) {
        if (req.getRole() == null || !CREATABLE_ROLES.contains(req.getRole())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Vai trò tạo được: EMPLOYEE, HR, HEAD_DEPARTMENT, HEAD_NURSING");
        }
        if (userAccountRepository.existsByUsername(req.getUsername())) {
            throw new ApiException(HttpStatus.CONFLICT, "Username đã tồn tại");
        }
        Department dept = departmentRepository.findById(req.getDepartmentId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban"));
        Position pos = positionRepository.findById(req.getPositionId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy chức vụ"));

        UserAccount user = UserAccount.builder()
                .username(req.getUsername())
                .passwordHash(passwordEncoder.encode(req.getPassword()))
                .email(req.getEmail())
                .role(req.getRole())
                .enabled(true)
                .build();
        user = userAccountRepository.save(user);

        Employee emp = Employee.builder()
                .user(user)
                .fullName(req.getFullName())
                .phone(req.getPhone())
                .idCardNumber(req.getIdCardNumber())
                .dateOfBirth(req.getDateOfBirth())
                .address(req.getAddress())
                .gender(req.getGender())
                .department(dept)
                .position(pos)
                .hireDate(req.getHireDate())
                .status(EmployeeStatus.ACTIVE)
                .build();
        emp = employeeRepository.save(emp);

        SalaryInfo salary = SalaryInfo.builder()
                .employee(emp)
                .baseSalary(req.getBaseSalary())
                .allowance(BigDecimal.ZERO)
                .lastRaiseDate(null)
                .nextReviewDate(req.getHireDate().plusYears(1))
                .build();
        salaryInfoRepository.save(salary);

        return loadDetail(emp);
    }

    /**
     * Danh sách nhân viên để chọn khi chấm điểm theo tháng: toàn bộ nhân viên ACTIVE (giống phạm vi HCNS cho mọi vai trò được phép vào phiếu).
     */
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Transactional(readOnly = true)
    public List<EmployeeSummaryDto> listEvaluationRoster() {
        currentUser(); // chỉ đảm bảo đã đăng nhập
        return employeeRepository
                .findByStatus(EmployeeStatus.ACTIVE, Sort.by("fullName"))
                .stream()
                .map(EmployeeMapper::toSummary)
                .toList();
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public EmployeeDetailDto update(Long id, EmployeeUpdateRequest req) {
        Employee e = employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        UserAccount user = e.getUser();
        if (req.getEmail() != null && !req.getEmail().isBlank()) {
            String em = req.getEmail().trim();
            if (!em.equalsIgnoreCase(user.getEmail())
                    && userAccountRepository.existsByEmailIgnoreCaseAndIdNot(em, user.getId())) {
                throw new ApiException(HttpStatus.CONFLICT, "Email đã được sử dụng");
            }
            user.setEmail(em);
        }
        if (req.getRole() != null) {
            user.setRole(req.getRole());
        }
        userAccountRepository.save(user);
        if (req.getFullName() != null) {
            e.setFullName(req.getFullName());
        }
        if (req.getPhone() != null) {
            e.setPhone(req.getPhone());
        }
        if (req.getIdCardNumber() != null) {
            e.setIdCardNumber(req.getIdCardNumber());
        }
        if (req.getDateOfBirth() != null) {
            e.setDateOfBirth(req.getDateOfBirth());
        }
        if (req.getAddress() != null) {
            e.setAddress(req.getAddress());
        }
        if (req.getGender() != null) {
            e.setGender(req.getGender());
        }
        if (req.getDepartmentId() != null) {
            e.setDepartment(departmentRepository.findById(req.getDepartmentId())
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban")));
        }
        if (req.getPositionId() != null) {
            e.setPosition(positionRepository.findById(req.getPositionId())
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy chức vụ")));
        }
        if (req.getHireDate() != null) {
            e.setHireDate(req.getHireDate());
        }
        e.setStatus(req.getStatus());
        employeeRepository.save(e);

        boolean touchSalary = req.getBaseSalary() != null || req.getAllowance() != null
                || req.getLastRaiseDate() != null || req.getNextReviewDate() != null;
        if (touchSalary) {
            SalaryInfo salary = salaryInfoRepository.findByEmployee(e).orElseGet(() ->
                    SalaryInfo.builder()
                            .employee(e)
                            .baseSalary(BigDecimal.ZERO)
                            .allowance(BigDecimal.ZERO)
                            .build());
            if (req.getBaseSalary() != null) {
                salary.setBaseSalary(req.getBaseSalary());
            }
            if (req.getAllowance() != null) {
                salary.setAllowance(req.getAllowance());
            }
            if (req.getLastRaiseDate() != null) {
                salary.setLastRaiseDate(req.getLastRaiseDate());
            }
            if (req.getNextReviewDate() != null) {
                salary.setNextReviewDate(req.getNextReviewDate());
            }
            salaryInfoRepository.save(salary);
        }

        return loadDetail(e);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public void delete(Long id) {
        Employee e = employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        e.setStatus(EmployeeStatus.TERMINATED);
        e.getUser().setEnabled(false);
        employeeRepository.save(e);
    }

    private EmployeeDetailDto loadDetail(Employee e) {
        SalaryInfo salary = salaryInfoRepository.findByEmployee(e).orElse(null);
        List<Contract> contracts = contractRepository.findByEmployeeOrderByStartDateDesc(e);
        EmployeeDetailDto base = EmployeeMapper.toDetail(e, salary, contracts);
        return employeeWorkforceDetailsRepository.findByEmployee(e)
                .map(w -> {
                    Map<String, Object> profile = WorkforceProfileMapper.toMap(w);
                    return profile.isEmpty() ? base : base.toBuilder().workforceProfile(profile).build();
                })
                .orElse(base);
    }

    private void assertCanAccessEmployee(Employee target) {
        UserAccount current = userAccountRepository.findByUsername(SecurityUtils.currentUsername())
                .orElseThrow();
        if (current.getRole() == UserRole.ADMIN || current.getRole() == UserRole.HR) {
            return;
        }
        employeeRepository.findByUser(current).ifPresentOrElse(self -> {
            if (self.getId().equals(target.getId())) {
                return;
            }
            if ((current.getRole() == UserRole.HEAD_DEPARTMENT || current.getRole() == UserRole.HEAD_NURSING)
                    && self.getDepartment().getId().equals(target.getDepartment().getId())) {
                return;
            }
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ xem được hồ sơ trong phạm vi được phân quyền");
        }, () -> {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền");
        });
    }

    @Transactional(readOnly = true)
    public Employee requireEmployeeEntity(Long id) {
        return employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
    }

    @Transactional(readOnly = true)
    public UserAccount currentUser() {
        return userAccountRepository.findByUsername(SecurityUtils.currentUsername())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "Chưa đăng nhập"));
    }
}
