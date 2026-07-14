package com.minhan.hrm.service;

import com.minhan.hrm.account.EmployeeAccountProvisioner;
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
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

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
    private final AttendanceWorkRequestRepository attendanceWorkRequestRepository;
    private final AttendanceRecordRepository attendanceRecordRepository;
    private final DutyShiftEntryRepository dutyShiftEntryRepository;
    private final PayrollRecordRepository payrollRecordRepository;
    private final NursingEvaluationRepository nursingEvaluationRepository;
    private final EvaluationRepository evaluationRepository;
    private final EmployeeSalaryProfileRepository employeeSalaryProfileRepository;
    private final EmployeeDocumentRepository employeeDocumentRepository;
    private final NotificationRepository notificationRepository;
    private final FileStorageService fileStorageService;
    private final EmployeeAccountProvisioner employeeAccountProvisioner;
    private final PasswordEncoder passwordEncoder;

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional(readOnly = true)
    public Page<EmployeeSummaryDto> list(
            Pageable pageable, String q, Long departmentId, EmployeeStatus status, EmployeeStatusGroup statusGroup,
            OfficialWorkFilter officialWorkFilter) {
        Specification<Employee> spec = EmployeeSpecifications.withFilters(
                q, departmentId, status, statusGroup, officialWorkFilter);
        Page<Employee> page = employeeRepository.findAll(spec, pageable);
        List<Employee> content = page.getContent();
        Map<Long, EmployeeWorkforceDetails> workforceByEmployeeId = content.isEmpty()
                ? Map.of()
                : employeeWorkforceDetailsRepository.findByEmployeeIn(content).stream()
                        .collect(Collectors.toMap(w -> w.getEmployee().getId(), Function.identity()));
        return page.map(emp -> EmployeeMapper.toSummary(emp, workforceByEmployeeId.get(emp.getId())));
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

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public EmployeeDetailDto create(EmployeeCreateRequest req) {
        if (req.getRole() == null || !CREATABLE_ROLES.contains(req.getRole())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Vai trò tạo được: EMPLOYEE, HR, HEAD_DEPARTMENT, HEAD_NURSING");
        }
        Department dept = departmentRepository.findById(req.getDepartmentId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban"));
        Position pos = positionRepository.findById(req.getPositionId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy chức vụ"));

        UserAccount user;
        if (req.getRole() == UserRole.EMPLOYEE) {
            if (req.getPhone() == null || req.getPhone().isBlank()) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Cần nhập số điện thoại — dùng làm tên đăng nhập (mật khẩu mặc định 123)");
            }
            user = employeeAccountProvisioner.buildNewEmployeeUser(
                    req.getPhone(), null, req.getEmail().trim());
            user = userAccountRepository.save(user);
        } else {
            if (req.getUsername() == null || req.getUsername().isBlank()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Cần username");
            }
            if (req.getPassword() == null || req.getPassword().isBlank()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Cần mật khẩu");
            }
            if (userAccountRepository.existsByUsername(req.getUsername())) {
                throw new ApiException(HttpStatus.CONFLICT, "Username đã tồn tại");
            }
            user = UserAccount.builder()
                    .username(req.getUsername().trim())
                    .passwordHash(passwordEncoder.encode(req.getPassword()))
                    .email(req.getEmail().trim())
                    .role(req.getRole())
                    .enabled(true)
                    .mustChangePassword(false)
                    .build();
            user = userAccountRepository.save(user);
        }

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

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
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

        if (req.getHireDate() != null && isTrialStatus(e.getStatus())) {
            syncProbationStartDate(e, req.getHireDate());
        }

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

    private static boolean isTrialStatus(EmployeeStatus status) {
        return status == EmployeeStatus.PROBATION || status == EmployeeStatus.INTERN;
    }

    private void syncProbationStartDate(Employee e, LocalDate startDate) {
        EmployeeWorkforceDetails w = employeeWorkforceDetailsRepository.findByEmployee(e)
                .orElse(EmployeeWorkforceDetails.builder().employee(e).build());
        w.setProbationStartDate(startDate);
        employeeWorkforceDetailsRepository.save(w);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void delete(Long id) {
        Employee e = employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        e.setStatus(EmployeeStatus.TERMINATED);
        e.getUser().setEnabled(false);
        employeeRepository.save(e);
    }

    /** Xóa vĩnh viễn hồ sơ nhân viên đã nghỉ việc (và tài khoản liên quan). */
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void permanentlyDelete(Long id) {
        Employee e = employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (e.getStatus() != EmployeeStatus.TERMINATED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ xóa hẳn được nhân viên đã nghỉ việc");
        }
        UserAccount user = e.getUser();
        Long employeeId = e.getId();

        deleteStoredDocuments(e);
        attendanceWorkRequestRepository.deleteByEmployee_Id(employeeId);
        attendanceRecordRepository.deleteByEmployee_Id(employeeId);
        dutyShiftEntryRepository.deleteByEmployee_Id(employeeId);
        payrollRecordRepository.deleteByEmployee_Id(employeeId);
        nursingEvaluationRepository.deleteByEmployee_Id(employeeId);
        evaluationRepository.deleteByEmployee_Id(employeeId);
        contractRepository.deleteByEmployee_Id(employeeId);
        employeeSalaryProfileRepository.deleteByEmployee_Id(employeeId);
        salaryInfoRepository.deleteByEmployee_Id(employeeId);
        employeeWorkforceDetailsRepository.deleteById(employeeId);
        notificationRepository.clearRelatedEmployee(employeeId);

        detachUserReferences(user);
        employeeRepository.delete(e);
        userAccountRepository.delete(user);
    }

    private void detachUserReferences(UserAccount user) {
        UserAccount fallback = userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HR)).stream()
                .filter(u -> !u.getId().equals(user.getId()))
                .findFirst()
                .orElseThrow(() -> new ApiException(HttpStatus.CONFLICT,
                        "Không xóa được tài khoản: cần tài khoản ADMIN/HR khác để chuyển dữ liệu tham chiếu"));
        nursingEvaluationRepository.reassignEvaluator(user, fallback);
        evaluationRepository.reassignEvaluator(user, fallback);
        employeeDocumentRepository.clearUploader(user);
        dutyShiftEntryRepository.clearEnteredBy(user);
        notificationRepository.deleteByUser_Id(user.getId());
    }

    private void deleteStoredDocuments(Employee employee) {
        employeeDocumentRepository.findByEmployeeOrderByCreatedAtDesc(employee).forEach(doc -> {
            try {
                Path path = fileStorageService.resolveStoredPath(doc.getStoredPath());
                Files.deleteIfExists(path);
            } catch (Exception ignored) {
                // vẫn xóa bản ghi DB
            }
        });
        employeeDocumentRepository.deleteByEmployee_Id(employee.getId());
    }

    /** Chuyển nhân viên thử việc / thực tập lên chính thức. */
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public EmployeeDetailDto confirmOfficial(Long id, LocalDate officialDate) {
        Employee e = employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (e.getStatus() != EmployeeStatus.PROBATION && e.getStatus() != EmployeeStatus.INTERN) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ chuyển chính thức được nhân viên thử việc hoặc thực tập");
        }
        LocalDate effective = officialDate != null ? officialDate : LocalDate.now();
        LocalDate previousHire = e.getHireDate();
        e.setStatus(EmployeeStatus.ACTIVE);
        e.setHireDate(effective);
        employeeRepository.save(e);

        EmployeeWorkforceDetails w = employeeWorkforceDetailsRepository.findByEmployee(e)
                .orElse(EmployeeWorkforceDetails.builder().employee(e).build());
        if (w.getProbationStartDate() == null) {
            w.setProbationStartDate(previousHire);
        }
        w.setOfficialStartDate(effective);
        employeeWorkforceDetailsRepository.save(w);

        return loadDetail(e);
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
