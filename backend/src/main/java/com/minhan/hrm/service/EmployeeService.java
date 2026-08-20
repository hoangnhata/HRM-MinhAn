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
import com.minhan.hrm.sso.SsoRoleService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmployeeService {

    private static final Set<UserRole> CREATABLE_ROLES = EnumSet.of(
            UserRole.EMPLOYEE, UserRole.HR, UserRole.HR2, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_HR,
            UserRole.HEAD_NURSING);

    private final EmployeeRepository employeeRepository;
    private final EmployeeLinkService employeeLinkService;
    private final UserAccountRepository userAccountRepository;
    private final DepartmentRepository departmentRepository;
    private final PositionRepository positionRepository;
    private final ContractRepository contractRepository;
    private final SalaryInfoRepository salaryInfoRepository;
    private final EmployeeWorkforceDetailsRepository employeeWorkforceDetailsRepository;
    private final AttendanceWorkRequestRepository attendanceWorkRequestRepository;
    private final AttendanceRecordRepository attendanceRecordRepository;
    private final ObjectProvider<SsoRoleService> ssoRoleService;
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

    @PersistenceContext
    private EntityManager entityManager;

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional(readOnly = true)
    public Page<EmployeeSummaryDto> list(
            Pageable pageable, String q, Long departmentId, String workUnitDetail, EmployeeStatus status,
            EmployeeStatusGroup statusGroup, OfficialWorkFilter officialWorkFilter) {
        return listInternal(pageable, q, departmentId, workUnitDetail, status, statusGroup, officialWorkFilter);
    }

    /**
     * Danh sách nhân viên — ADMIN / HR / DIRECTOR xem toàn viện;
     * trưởng khoa / ĐDT chỉ xem nhân lực khoa mình (bắt buộc gắn hồ sơ NV có phòng ban);
     * Trưởng phòng ĐD xem toàn viện nhưng chỉ khối ĐD–KTV–HS–Thư ký y khoa.
     */
    @PreAuthorize("hasAnyRole('ADMIN','HR','HR2','DIRECTOR','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Transactional(readOnly = true)
    public Page<EmployeeSummaryDto> listForCaller(
            Pageable pageable, String q, Long departmentId, String workUnitDetail, EmployeeStatus status,
            EmployeeStatusGroup statusGroup, OfficialWorkFilter officialWorkFilter) {
        UserAccount caller = currentUser();
        // HEAD_HR vừa là trưởng khoa vừa HCNS 2: danh sách nhân sự theo HCNS 2 (toàn viện).
        if (!isHr2Role(caller)) {
            Long scopedDept = resolveHeadDepartmentScope(caller);
            if (scopedDept != null) {
                departmentId = scopedDept;
            }
            String scopedUnit = resolveHeadWorkUnitScope(caller);
            if (scopedUnit != null) {
                workUnitDetail = scopedUnit;
            }
        }
        if (caller != null && caller.getRole() == UserRole.HEAD_NURSING) {
            return filterNursingBlockPage(
                    pageable, q, departmentId, workUnitDetail, status, statusGroup, officialWorkFilter);
        }
        return listInternal(
                pageable, q, departmentId, workUnitDetail, status, statusGroup, officialWorkFilter);
    }

    private Page<EmployeeSummaryDto> filterNursingBlockPage(
            Pageable pageable, String q, Long departmentId, String workUnitDetail, EmployeeStatus status,
            EmployeeStatusGroup statusGroup, OfficialWorkFilter officialWorkFilter) {
        Specification<Employee> spec = EmployeeSpecifications.withFilters(
                q, departmentId, workUnitDetail, status, statusGroup, officialWorkFilter);
        List<Employee> all = employeeRepository.findAll(spec, Sort.unsorted()).stream()
                .filter(NursingBlockClassifier::matches)
                .toList();
        int from = (int) pageable.getOffset();
        int to = Math.min(from + pageable.getPageSize(), all.size());
        List<Employee> slice = from >= all.size() ? List.of() : all.subList(from, to);
        Map<Long, EmployeeWorkforceDetails> workforceByEmployeeId = slice.isEmpty()
                ? Map.of()
                : employeeWorkforceDetailsRepository.findByEmployeeIn(slice).stream()
                        .collect(Collectors.toMap(w -> w.getEmployee().getId(), Function.identity()));
        List<EmployeeSummaryDto> content = slice.stream()
                .map(emp -> EmployeeMapper.toSummary(emp, workforceByEmployeeId.get(emp.getId())))
                .toList();
        return new org.springframework.data.domain.PageImpl<>(content, pageable, all.size());
    }

    private Page<EmployeeSummaryDto> listInternal(
            Pageable pageable, String q, Long departmentId, String workUnitDetail, EmployeeStatus status,
            EmployeeStatusGroup statusGroup, OfficialWorkFilter officialWorkFilter) {
        Specification<Employee> spec = EmployeeSpecifications.withFilters(
                q, departmentId, workUnitDetail, status, statusGroup, officialWorkFilter);
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
        Employee e = employeeLinkService.findLinkedEmployee(currentUser())
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
        UserAccount actor = currentUser();
        if (req.getRole() == null || !CREATABLE_ROLES.contains(req.getRole())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Vai trò tạo được: EMPLOYEE, HR, HR2, HEAD_DEPARTMENT, HEAD_HR, HEAD_NURSING");
        }
        if (isHeadRole(actor) && req.getRole() != UserRole.EMPLOYEE) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Trưởng chỉ được tạo tài khoản nhân viên thường");
        }
        Long headDeptId = resolveHeadDepartmentScope(actor);
        Long departmentId = req.getDepartmentId();
        if (headDeptId != null) {
            if (departmentId != null && !departmentId.equals(headDeptId)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ được tạo nhân viên thuộc khoa của bạn");
            }
            departmentId = headDeptId;
        }
        if (departmentId == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần chọn khoa / phòng ban");
        }
        Department dept = departmentRepository.findById(departmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phòng ban"));
        Position pos = resolvePositionOrDefault(req.getPositionId());

        String attendanceCode = req.getWorkforce() != null
                ? blankToNull(req.getWorkforce().getAttendanceCode())
                : null;
        if (attendanceCode == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập mã chấm công");
        }

        String scopedUnit = resolveHeadWorkUnitScope(actor);
        if (scopedUnit != null) {
            WorkforceDetailsRequest wfReq = req.getWorkforce() != null
                    ? req.getWorkforce()
                    : new WorkforceDetailsRequest();
            if (wfReq.getWorkUnitDetail() != null
                    && !wfReq.getWorkUnitDetail().isBlank()
                    && !scopedUnit.equalsIgnoreCase(wfReq.getWorkUnitDetail().trim())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ được tạo nhân viên thuộc bộ phận của bạn");
            }
            wfReq.setWorkUnitDetail(scopedUnit);
            req.setWorkforce(wfReq);
        }

        String phoneNorm = employeeAccountProvisioner.normalizePhoneUsername(req.getPhone());
        if (req.getRole() == UserRole.EMPLOYEE && (phoneNorm == null || phoneNorm.isBlank())) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Cần nhập số điện thoại — dùng làm tên đăng nhập (mật khẩu mặc định 123)");
        }

        String email;
        if (req.getEmail() != null && !req.getEmail().isBlank()) {
            email = req.getEmail().trim();
            if (!email.contains("@")) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Email không hợp lệ");
            }
        } else {
            email = phoneNorm != null && !phoneNorm.isBlank()
                    ? phoneNorm + "@minhan.local"
                    : "nv" + System.currentTimeMillis() + "@minhan.local";
        }

        UserAccount user;
        if (req.getRole() == UserRole.EMPLOYEE) {
            String idCardEarly = normalizeIdCardDigits(req.getIdCardNumber());
            releaseTerminatedIdentityConflicts(phoneNorm, idCardEarly);
            user = employeeAccountProvisioner.buildNewEmployeeUser(phoneNorm, null, email);
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
                    .email(email)
                    .role(req.getRole())
                    .enabled(true)
                    .mustChangePassword(false)
                    .build();
            user = userAccountRepository.save(user);
        }

        String idCard = normalizeIdCardDigits(req.getIdCardNumber());
        if (idCard != null) {
            releaseTerminatedIdentityConflicts(phoneNorm, idCard);
            ensureUniqueEmployeeCodeAndIdCard(idCard, null);
        }
        String employeeCode = idCard != null
                ? idCard
                : allocateTemporaryEmployeeCode(phoneNorm, attendanceCode);

        LocalDate hireDate = req.getHireDate() != null ? req.getHireDate() : LocalDate.now();
        BigDecimal baseSalary = req.getBaseSalary() != null ? req.getBaseSalary() : BigDecimal.ZERO;
        EmploymentType employmentType = req.getEmploymentType() != null
                ? req.getEmploymentType()
                : EmploymentType.FULL_TIME;

        Employee emp = Employee.builder()
                .user(user)
                .employeeCode(employeeCode)
                .fullName(req.getFullName().trim())
                .phone(phoneNorm != null ? phoneNorm : req.getPhone())
                .idCardNumber(idCard)
                .dateOfBirth(req.getDateOfBirth())
                .address(req.getAddress())
                .gender(req.getGender())
                .department(dept)
                .position(pos)
                .hireDate(hireDate)
                .status(req.getStatus() != null ? req.getStatus() : EmployeeStatus.ACTIVE)
                .employmentType(employmentType)
                .build();
        emp = employeeRepository.save(emp);

        SalaryInfo salary = SalaryInfo.builder()
                .employee(emp)
                .baseSalary(baseSalary)
                .allowance(BigDecimal.ZERO)
                .lastRaiseDate(null)
                .nextReviewDate(hireDate.plusYears(1))
                .build();
        salaryInfoRepository.save(salary);

        applyWorkforceDetails(emp, req.getWorkforce(), emp.getStatus(), emp.getHireDate());

        syncHrmRoleToSso(emp.getPhone(), user.getUsername(), user.getRole());
        return loadDetail(emp);
    }

    private Position resolvePositionOrDefault(Long positionId) {
        if (positionId != null) {
            return positionRepository.findById(positionId)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy chức vụ"));
        }
        return positionRepository.findFirstByTitleIgnoreCaseOrderByIdAsc("Nhân viên")
                .or(() -> positionRepository.findByCode("NV"))
                .or(() -> positionRepository.findAll(Sort.by("id")).stream().findFirst())
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST,
                        "Chưa có chức vụ trong hệ thống — hãy tạo chức vụ trước"));
    }

    /** Mã NV tạm khi chưa có CCCD — cấp tài khoản trước, bổ sung CCCD sau. */
    private String allocateTemporaryEmployeeCode(String phoneNorm, String attendanceCode) {
        String seed = phoneNorm != null && !phoneNorm.isBlank()
                ? phoneNorm
                : (attendanceCode != null ? attendanceCode.replaceAll("\\D", "") : null);
        if (seed == null || seed.isBlank()) {
            seed = Long.toString(System.currentTimeMillis());
        }
        String base = "TMP-" + seed;
        if (base.length() > 64) {
            base = base.substring(0, 64);
        }
        String code = base;
        int i = 0;
        while (employeeRepository.existsByEmployeeCode(code)) {
            String suffix = "-" + (++i);
            code = base.substring(0, Math.min(base.length(), 64 - suffix.length())) + suffix;
        }
        return code;
    }

    /**
     * Danh sách nhân viên để chọn khi chấm điểm theo tháng.
     * ADMIN/HR: toàn viện ACTIVE; trưởng khoa/ĐDT: chỉ khoa mình.
     */
    @PreAuthorize("hasAnyRole('ADMIN','HR','HR2','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Transactional(readOnly = true)
    public List<EmployeeSummaryDto> listEvaluationRoster() {
        UserAccount caller = currentUser();
        Long scopedDept = resolveHeadDepartmentScope(caller);
        String scopedUnit = resolveHeadWorkUnitScope(caller);
        List<Employee> list = scopedDept != null
                ? employeeRepository.findByDepartment_IdAndStatus(scopedDept, EmployeeStatus.ACTIVE, Sort.by("fullName"))
                : employeeRepository.findByStatus(EmployeeStatus.ACTIVE, Sort.by("fullName"));
        if (scopedUnit != null) {
            String unitKey = scopedUnit.trim().toLowerCase();
            list = list.stream()
                    .filter(e -> {
                        String u = employeeWorkforceDetailsRepository.findByEmployee(e)
                                .map(EmployeeWorkforceDetails::getWorkUnitDetail)
                                .map(String::trim)
                                .orElse("");
                        return unitKey.equalsIgnoreCase(u);
                    })
                    .toList();
        }
        // Chỉ khối ĐD–KTV–HS–Thư ký
        list = list.stream().filter(NursingBlockClassifier::matches).toList();
        if (caller.getRole() == UserRole.HEAD_NURSING) {
            // toàn khối
            return list.stream().map(EmployeeMapper::toSummary).toList();
        }
        return list.stream().map(EmployeeMapper::toSummary).toList();
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public EmployeeDetailDto update(Long id, EmployeeUpdateRequest req) {
        Employee e = employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        UserAccount actor = currentUser();
        assertCanAccessEmployee(e);
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
            if (isHeadRole(actor) && req.getRole() != UserRole.EMPLOYEE) {
                throw new ApiException(HttpStatus.FORBIDDEN, "Trưởng chỉ được gán vai trò nhân viên thường");
            }
            user.setRole(req.getRole());
        }
        userAccountRepository.save(user);
        if (req.getFullName() != null) {
            e.setFullName(req.getFullName());
        }
        if (req.getPhone() != null) {
            syncPhoneAndLoginUsername(e, req.getPhone());
        }
        if (req.getIdCardNumber() != null) {
            String raw = req.getIdCardNumber().trim();
            if (raw.isEmpty()) {
                // Cho phép hồ sơ tạm (chưa có CCCD)
            } else {
                String idCard = normalizeIdCardDigits(raw);
                if (idCard == null) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "CCCD/CMND không hợp lệ");
                }
                ensureUniqueEmployeeCodeAndIdCard(idCard, e.getId());
                e.setIdCardNumber(idCard);
                e.setEmployeeCode(idCard);
            }
        } else if (e.getEmployeeCode() == null || e.getEmployeeCode().isBlank()) {
            // Bổ sung mã NV từ CCCD đã có trên hồ sơ (NV cũ thiếu mã)
            String existingId = normalizeIdCardDigits(e.getIdCardNumber());
            if (existingId != null) {
                ensureUniqueEmployeeCodeAndIdCard(existingId, e.getId());
                e.setEmployeeCode(existingId);
            }
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
            Long headDeptId = resolveHeadDepartmentScope(actor);
            if (headDeptId != null && !headDeptId.equals(req.getDepartmentId())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "Không được chuyển nhân viên sang khoa khác");
            }
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
        if (req.getMainDutyAuthorized() != null) {
            e.setMainDutyAuthorized(req.getMainDutyAuthorized());
        }
        if (req.getEmploymentType() != null) {
            e.setEmploymentType(req.getEmploymentType());
        }
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

        if (req.getRole() != null || req.getPhone() != null) {
            syncHrmRoleToSso(e.getPhone(), user.getUsername(), user.getRole());
        }
        if (req.getWorkforce() != null) {
            applyWorkforceDetails(e, req.getWorkforce(), e.getStatus(), e.getHireDate());
        }
        return loadDetail(e);
    }

    private void applyWorkforceDetails(
            Employee emp, WorkforceDetailsRequest req, EmployeeStatus status, LocalDate hireDate) {
        EmployeeWorkforceDetails w = employeeWorkforceDetailsRepository.findByEmployee(emp)
                .orElseGet(() -> EmployeeWorkforceDetails.builder().employee(emp).build());

        if (req != null) {
            if (req.getPayrollDisplayName() != null) {
                w.setPayrollDisplayName(blankToNull(req.getPayrollDisplayName()));
            }
            if (req.getSpecialty() != null) {
                w.setSpecialty(blankToNull(req.getSpecialty()));
            }
            if (req.getDegree() != null) {
                w.setDegree(blankToNull(req.getDegree()));
            }
            if (req.getProfessionalDiploma() != null) {
                w.setProfessionalDiploma(blankToNull(req.getProfessionalDiploma()));
            }
            if (req.getPracticeScope() != null) {
                w.setPracticeScope(blankToNull(req.getPracticeScope()));
            }
            if (req.getPracticeCertNumber() != null) {
                w.setPracticeCertNumber(blankToNull(req.getPracticeCertNumber()));
            }
            if (req.getPracticeCertDateRaw() != null) {
                w.setPracticeCertDateRaw(blankToNull(req.getPracticeCertDateRaw()));
            }
            if (req.getOtherTrainingCertificates() != null) {
                w.setOtherTrainingCertificates(blankToNull(req.getOtherTrainingCertificates()));
            }
            if (req.getCki() != null) {
                w.setCki(blankToNull(req.getCki()));
            }
            if (req.getBankAccount() != null) {
                w.setBankAccount(normalizeBankAccount(req.getBankAccount()));
            }
            if (req.getBankName() != null) {
                w.setBankName(blankToNull(req.getBankName()));
            }
            if (req.getAttendanceCode() != null) {
                w.setAttendanceCode(normalizeUniqueAttendanceCode(emp, req.getAttendanceCode()));
            }
            if (req.getInsuranceParticipation() != null) {
                w.setInsuranceParticipation(blankToNull(req.getInsuranceParticipation()));
            }
            if (req.getSocialInsuranceBook() != null) {
                w.setSocialInsuranceBook(blankToNull(req.getSocialInsuranceBook()));
            }
            if (req.getIdCardIssueDate() != null) {
                w.setIdCardIssueDate(req.getIdCardIssueDate());
            }
            if (req.getProbationStartDate() != null) {
                w.setProbationStartDate(req.getProbationStartDate());
            }
            if (req.getOfficialStartDate() != null) {
                w.setOfficialStartDate(req.getOfficialStartDate());
            }
            if (req.getContractNumber() != null) {
                w.setContractNumber(blankToNull(req.getContractNumber()));
            }
            if (req.getContractSignDate() != null) {
                w.setContractSignDate(req.getContractSignDate());
            }
            if (req.getContractTerm() != null) {
                w.setContractTerm(blankToNull(req.getContractTerm()));
            }
            if (req.getWorkUnitDetail() != null) {
                w.setWorkUnitDetail(blankToNull(req.getWorkUnitDetail()));
            }
            if (req.getWorkforceNotes() != null) {
                w.setWorkforceNotes(blankToNull(req.getWorkforceNotes()));
            }
            if (req.getDependentsInfo() != null) {
                w.setDependentsInfo(blankToNull(req.getDependentsInfo()));
            }
            if (req.getEthnicity() != null) {
                w.setEthnicity(blankToNull(req.getEthnicity()));
            }
            if (req.getPlaceOfOrigin() != null) {
                w.setPlaceOfOrigin(blankToNull(req.getPlaceOfOrigin()));
            }
            if (req.getMaritalStatus() != null) {
                w.setMaritalStatus(blankToNull(req.getMaritalStatus()));
            }
            if (req.getBloodType() != null) {
                w.setBloodType(blankToNull(req.getBloodType()));
            }
            if (req.getEmergencyContact() != null) {
                w.setEmergencyContact(blankToNull(req.getEmergencyContact()));
            }
            if (req.getEmergencyPhone() != null) {
                w.setEmergencyPhone(blankToNull(req.getEmergencyPhone()));
            }
            if (w.getPayrollDisplayName() == null || w.getPayrollDisplayName().isBlank()) {
                w.setPayrollDisplayName(emp.getFullName());
            }
        }

        // Mặc định ngày thử việc / chính thức theo trạng thái nếu chưa nhập
        if (isTrialStatus(status) && w.getProbationStartDate() == null && hireDate != null) {
            w.setProbationStartDate(hireDate);
        }
        if (status == EmployeeStatus.ACTIVE && w.getOfficialStartDate() == null && hireDate != null) {
            w.setOfficialStartDate(hireDate);
        }

        employeeWorkforceDetailsRepository.save(w);
    }

    /**
     * Cập nhật định danh tài khoản từ màn quản trị. SĐT và mã chấm công vẫn được
     * lưu trên hồ sơ nhân viên để form nhân viên và màn tài khoản luôn đọc cùng dữ liệu.
     * SĐT liên hệ luôn khớp username đăng nhập.
     */
    public void updateAccountIdentifiers(Employee employee, String phone, String attendanceCode) {
        if (phone != null) {
            syncPhoneAndLoginUsername(employee, phone);
        } else {
            // Không gửi SĐT mới — vẫn chỉnh lại nếu TK và SĐT đang lệch nhau.
            ensurePhoneMatchesLoginUsername(employee);
        }

        if (attendanceCode != null) {
            EmployeeWorkforceDetails workforce = employeeWorkforceDetailsRepository.findByEmployee(employee)
                    .orElseGet(() -> EmployeeWorkforceDetails.builder().employee(employee).build());
            workforce.setAttendanceCode(normalizeUniqueAttendanceCode(employee, attendanceCode));
            employeeWorkforceDetailsRepository.save(workforce);
        }
    }

    /**
     * Đồng bộ SĐT liên hệ ↔ username đăng nhập (một bên đổi thì bên kia theo).
     */
    public void syncPhoneAndLoginUsername(Employee employee, String rawPhone) {
        String phone = employeeAccountProvisioner.normalizePhoneUsername(rawPhone);
        if (phone == null || phone.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Số điện thoại không hợp lệ");
        }

        String currentPhone = employeeAccountProvisioner.normalizePhoneUsername(employee.getPhone());
        UserAccount user = employee.getUser();
        String currentUsername = user != null
                ? employeeAccountProvisioner.normalizePhoneUsername(user.getUsername())
                : null;
        if (phone.equals(currentPhone)
                && (user == null || phone.equals(user.getUsername()) || phone.equals(currentUsername))) {
            // Đã khớp — vẫn ghi đè dạng chuẩn hóa nếu cần
            if (!phone.equals(employee.getPhone())) {
                employee.setPhone(phone);
                employeeRepository.save(employee);
            }
            return;
        }

        String tail = phone.length() >= 9 ? phone.substring(phone.length() - 9) : phone;
        for (Employee other : employeeRepository.findByPhoneEndingWith(tail)) {
            if (other.getId().equals(employee.getId())
                    || !phone.equals(employeeAccountProvisioner.normalizePhoneUsername(other.getPhone()))) {
                continue;
            }
            if (other.getStatus() == EmployeeStatus.TERMINATED) {
                releaseIdentityForReuse(other);
                continue;
            }
            throw new ApiException(HttpStatus.CONFLICT, "Số điện thoại đã gắn với nhân viên khác");
        }

        if (user != null && !phone.equals(user.getUsername())) {
            userAccountRepository.findByUsername(phone).ifPresent(other -> {
                if (other.getId().equals(user.getId())) {
                    return;
                }
                Employee linked = employeeRepository.findByUser(other).orElse(null);
                if (linked != null && linked.getStatus() == EmployeeStatus.TERMINATED) {
                    releaseIdentityForReuse(linked);
                    return;
                }
                throw new ApiException(HttpStatus.CONFLICT,
                        "Số điện thoại đã là tên đăng nhập của tài khoản khác");
            });

            String oldUsername = user.getUsername();
            if (user.getEmail() != null
                    && oldUsername != null
                    && user.getEmail().equalsIgnoreCase(oldUsername + "@minhan.local")) {
                user.setEmail(phone + "@minhan.local");
            }
            user.setUsername(phone);
            userAccountRepository.save(user);
        }

        employee.setPhone(phone);
        employeeRepository.save(employee);
    }

    /** Nếu SĐT và TK đang lệch — ưu tiên SĐT (nếu hợp lệ), không thì lấy TK nếu là SĐT. */
    public void ensurePhoneMatchesLoginUsername(Employee employee) {
        if (employee == null) {
            return;
        }
        UserAccount user = employee.getUser();
        String phoneNorm = employeeAccountProvisioner.normalizePhoneUsername(employee.getPhone());
        String userNorm = user != null
                ? employeeAccountProvisioner.normalizePhoneUsername(user.getUsername())
                : null;
        if (phoneNorm != null && !phoneNorm.isBlank()) {
            if (user == null || phoneNorm.equals(user.getUsername())) {
                if (!phoneNorm.equals(employee.getPhone())) {
                    employee.setPhone(phoneNorm);
                    employeeRepository.save(employee);
                }
                return;
            }
            syncPhoneAndLoginUsername(employee, phoneNorm);
            return;
        }
        if (userNorm != null && !userNorm.isBlank()) {
            syncPhoneAndLoginUsername(employee, userNorm);
        }
    }

    private String normalizeUniqueAttendanceCode(Employee employee, String rawAttendanceCode) {
        String attendanceCode = blankToNull(rawAttendanceCode);
        if (attendanceCode == null) {
            return null;
        }
        employeeWorkforceDetailsRepository.findByAttendanceCode(attendanceCode).ifPresent(other -> {
            if (other.getEmployeeId().equals(employee.getId())) {
                return;
            }
            Employee linked = employeeRepository.findById(other.getEmployeeId()).orElse(null);
            if (linked != null && linked.getStatus() == EmployeeStatus.TERMINATED) {
                releaseIdentityForReuse(linked);
                return;
            }
            throw new ApiException(HttpStatus.CONFLICT, "Mã chấm công đã được dùng bởi nhân viên khác");
        });
        return attendanceCode;
    }

    private static String blankToNull(String s) {
        return s != null && !s.isBlank() ? s.trim() : null;
    }

    /** CCCD/CMND chỉ giữ chữ số (bỏ khoảng trắng, dấu). */
    static String normalizeIdCardDigits(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String digits = raw.replaceAll("\\D", "");
        return digits.isEmpty() ? null : digits;
    }

    private void ensureUniqueEmployeeCodeAndIdCard(String idCard, Long excludeEmployeeId) {
        employeeRepository.findByEmployeeCode(idCard).ifPresent(other -> {
            if (excludeEmployeeId != null && other.getId().equals(excludeEmployeeId)) {
                return;
            }
            if (other.getStatus() == EmployeeStatus.TERMINATED) {
                releaseIdentityForReuse(other);
                return;
            }
            throw new ApiException(HttpStatus.CONFLICT, "Mã nhân viên (CCCD) đã được dùng bởi nhân viên khác");
        });
        employeeRepository.findByIdCardNumberNormalized(idCard).ifPresent(other -> {
            if (excludeEmployeeId != null && other.getId().equals(excludeEmployeeId)) {
                return;
            }
            if (other.getStatus() == EmployeeStatus.TERMINATED) {
                releaseIdentityForReuse(other);
                return;
            }
            throw new ApiException(HttpStatus.CONFLICT, "CCCD/CMND đã được dùng bởi nhân viên khác");
        });
    }

    /**
     * Giải phóng SĐT / username / CCCD / mã NV / mã chấm công để tạo lại hồ sơ mới được.
     * Hồ sơ nghỉ việc vẫn giữ tên để tra cứu lịch sử.
     */
    private void releaseIdentityForReuse(Employee e) {
        if (e == null || e.getId() == null) {
            return;
        }
        Long id = e.getId();
        String stamp = Long.toString(System.currentTimeMillis());
        UserAccount user = e.getUser();
        if (user != null) {
            String freedUsername = ("del_" + id + "_" + stamp);
            if (freedUsername.length() > 64) {
                freedUsername = freedUsername.substring(0, 64);
            }
            user.setUsername(freedUsername);
            user.setEmail("del_" + id + "_" + stamp + "@deleted.local");
            user.setEnabled(false);
            userAccountRepository.save(user);
        }
        String freedCode = "DEL-" + id + "-" + stamp;
        if (freedCode.length() > 64) {
            freedCode = freedCode.substring(0, 64);
        }
        e.setEmployeeCode(freedCode);
        e.setPhone(null);
        e.setIdCardNumber(null);
        employeeWorkforceDetailsRepository.findByEmployee(e).ifPresent(w -> {
            w.setAttendanceCode(null);
            employeeWorkforceDetailsRepository.save(w);
        });
        employeeRepository.save(e);
        entityManager.flush();
    }

    /** Hồ sơ nghỉ việc còn giữ SĐT/CCCD cũ — giải phóng trước khi tạo/gán lại. */
    private void releaseTerminatedIdentityConflicts(String rawPhone, String idCard) {
        String phone = employeeAccountProvisioner.normalizePhoneUsername(rawPhone);
        if (phone != null && !phone.isBlank()) {
            String tail = phone.length() >= 9 ? phone.substring(phone.length() - 9) : phone;
            for (Employee other : employeeRepository.findByPhoneEndingWith(tail)) {
                if (other.getStatus() == EmployeeStatus.TERMINATED
                        && phone.equals(employeeAccountProvisioner.normalizePhoneUsername(other.getPhone()))) {
                    releaseIdentityForReuse(other);
                }
            }
            userAccountRepository.findByUsername(phone).ifPresent(other ->
                    employeeRepository.findByUser(other).ifPresent(linked -> {
                        if (linked.getStatus() == EmployeeStatus.TERMINATED) {
                            releaseIdentityForReuse(linked);
                        }
                    }));
        }
        if (idCard != null && !idCard.isBlank()) {
            employeeRepository.findByEmployeeCode(idCard).ifPresent(other -> {
                if (other.getStatus() == EmployeeStatus.TERMINATED) {
                    releaseIdentityForReuse(other);
                }
            });
            employeeRepository.findByIdCardNumberNormalized(idCard).ifPresent(other -> {
                if (other.getStatus() == EmployeeStatus.TERMINATED) {
                    releaseIdentityForReuse(other);
                }
            });
        }
    }

    /** Tránh lưu dạng scientific notation từ Excel (vd. 3.60422E+12). */
    private static String normalizeBankAccount(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String t = raw.trim().replace(",", "").replace(" ", "");
        if (t.matches("(?i)\\d+(\\.\\d+)?[eE][+-]?\\d+")) {
            try {
                return new java.math.BigDecimal(t).toPlainString();
            } catch (NumberFormatException ignored) {
                // fall through
            }
        }
        // Chỉ giữ chữ số nếu chuỗi toàn số / dấu
        String digits = t.replaceAll("[^0-9]", "");
        if (!digits.isEmpty() && digits.length() >= 6) {
            return digits;
        }
        return t;
    }

    private static boolean isTrialStatus(EmployeeStatus status) {
        return status == EmployeeStatus.PROBATION || status == EmployeeStatus.INTERN;
    }

    /** NV thử việc/thực tập chỉ xem lương khi đã có ngày vào làm chính thức. */
    @Transactional(readOnly = true)
    public boolean canViewOwnSalary(Employee emp) {
        if (emp == null) {
            return false;
        }
        if (!isTrialStatus(emp.getStatus())) {
            return true;
        }
        return employeeWorkforceDetailsRepository.findByEmployee(emp)
                .map(w -> w.getOfficialStartDate() != null)
                .orElse(false);
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
        assertCanAccessEmployee(e);
        e.setStatus(EmployeeStatus.TERMINATED);
        releaseIdentityForReuse(e);
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
        deleteAllEmployeeOwnedRows(employeeId);
        notificationRepository.clearRelatedEmployee(employeeId);

        detachUserReferences(user);
        employeeRepository.delete(e);
        entityManager.flush();
        userAccountRepository.delete(user);
    }

    /** Xóa mọi bản ghi gắn employee_id — tránh sót FK khiến không xóa được / còn dữ liệu trùng SĐT. */
    private void deleteAllEmployeeOwnedRows(Long employeeId) {
        String[] tables = {
                "attendance_work_request",
                "attendance_records",
                "duty_shift_entry",
                "payroll_records",
                "nursing_evaluations",
                "evaluations",
                "contracts",
                "employee_documents",
                "employee_salary_profile",
                "salary_info",
                "employee_workforce_details",
                "employee_attendance_shift_config",
                "employee_continuous_shift_day",
                "employee_continuous_shift_month",
                "employee_young_child_month",
                "young_child_requests",
                "training_proposal_requests",
                "seminar_proposal_requests",
                "main_duty_authorization_requests",
                "department_transfer_requests",
                "probation_conversion_requests",
        };
        for (String table : tables) {
            entityManager.createNativeQuery("DELETE FROM " + table + " WHERE employee_id = :id")
                    .setParameter("id", employeeId)
                    .executeUpdate();
        }
    }

    private void detachUserReferences(UserAccount user) {
        UserAccount fallback = userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HR)).stream()
                .filter(u -> !u.getId().equals(user.getId()))
                .findFirst()
                .orElseThrow(() -> new ApiException(HttpStatus.CONFLICT,
                        "Không xóa được tài khoản: cần tài khoản ADMIN/HR khác để chuyển dữ liệu tham chiếu"));
        Long uid = user.getId();
        Long fb = fallback.getId();

        nursingEvaluationRepository.reassignEvaluator(user, fallback);
        nursingEvaluationRepository.reassignHeadReviewer(user, fallback);
        nursingEvaluationRepository.reassignHrReviewer(user, fallback);
        nursingEvaluationRepository.reassignDirectorReviewer(user, fallback);
        evaluationRepository.reassignEvaluator(user, fallback);
        employeeDocumentRepository.clearUploader(user);
        dutyShiftEntryRepository.clearEnteredBy(user);
        notificationRepository.deleteByUser_Id(uid);

        // Đơn / phiếu do user này gửi hoặc duyệt (của NV khác) — chuyển sang ADMIN/HR còn lại
        String[] requestedByTables = {
                "young_child_requests",
                "training_proposal_requests",
                "seminar_proposal_requests",
                "main_duty_authorization_requests",
                "department_transfer_requests",
                "probation_conversion_requests",
        };
        for (String table : requestedByTables) {
            entityManager.createNativeQuery(
                            "UPDATE " + table + " SET requested_by_user_id = :fb WHERE requested_by_user_id = :uid")
                    .setParameter("fb", fb)
                    .setParameter("uid", uid)
                    .executeUpdate();
        }
        entityManager.createNativeQuery(
                        "UPDATE internal_announcements SET author_user_id = :fb WHERE author_user_id = :uid")
                .setParameter("fb", fb)
                .setParameter("uid", uid)
                .executeUpdate();

        clearNullableReviewer(uid, "attendance_work_request",
                "head_reviewer_id", "hr_reviewer_id", "director_reviewer_id");
        clearNullableReviewer(uid, "young_child_requests", "hr_reviewer_id");
        clearNullableReviewer(uid, "training_proposal_requests", "hr_reviewer_id", "director_reviewer_id");
        clearNullableReviewer(uid, "seminar_proposal_requests", "hr_reviewer_id", "director_reviewer_id");
        clearNullableReviewer(uid, "main_duty_authorization_requests",
                "head_reviewer_id", "hr_reviewer_id", "director_reviewer_id");
        clearNullableReviewer(uid, "department_transfer_requests", "director_reviewer_id");
        clearNullableReviewer(uid, "probation_conversion_requests", "hr_reviewer_id", "director_reviewer_id");
    }

    private void clearNullableReviewer(Long userId, String table, String... columns) {
        for (String col : columns) {
            entityManager.createNativeQuery(
                            "UPDATE " + table + " SET " + col + " = NULL WHERE " + col + " = :uid")
                    .setParameter("uid", userId)
                    .executeUpdate();
        }
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

    /** Chuyển nhân viên thử việc / thực tập lên chính thức (API HCNS — giữ tương thích). */
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public EmployeeDetailDto confirmOfficial(Long id, LocalDate officialDate) {
        return applyOfficialInternal(id, officialDate);
    }

    /**
     * Áp dụng chuyển chính thức — dùng nội bộ từ đơn duyệt (không kiểm tra role).
     */
    @Transactional
    public EmployeeDetailDto applyOfficialInternal(Long id, LocalDate officialDate) {
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

    /**
     * Hoàn tác chuyển chính thức khi thu hồi đơn đã áp dụng (nội bộ).
     * Khôi phục trạng thái thử việc và ngày vào làm từ mốc thử việc đã lưu.
     */
    @Transactional
    public void revertOfficialInternal(Long id) {
        Employee e = employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));
        if (e.getStatus() != EmployeeStatus.ACTIVE) {
            return;
        }
        EmployeeWorkforceDetails w = employeeWorkforceDetailsRepository.findByEmployee(e).orElse(null);
        LocalDate probationHire = w != null && w.getProbationStartDate() != null
                ? w.getProbationStartDate()
                : e.getHireDate();
        e.setStatus(EmployeeStatus.PROBATION);
        if (probationHire != null) {
            e.setHireDate(probationHire);
        }
        employeeRepository.save(e);
        if (w != null) {
            w.setOfficialStartDate(null);
            employeeWorkforceDetailsRepository.save(w);
        }
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

    /**
     * Kiểm tra quyền xem/sửa hồ sơ nhân viên (public để các service khác tái sử dụng).
     * ADMIN/HR/DIRECTOR: toàn viện; trưởng khoa/ĐDT: cùng phòng ban;
     * HEAD_NURSING: khối ĐD–KTV–HS–Thư ký y khoa; còn lại: chỉ bản thân.
     */
    public void assertCanAccessEmployee(Employee target) {
        UserAccount current = currentUser();
        if (canViewHospitalWide(current) || isHr2Role(current)) {
            return;
        }
        // Bản thân luôn được xem/cập nhật hồ sơ & công của mình (kể cả HEAD_NURSING / trưởng khoa).
        var linkedSelf = employeeLinkService.findLinkedEmployee(current);
        if (linkedSelf.isPresent() && linkedSelf.get().getId().equals(target.getId())) {
            return;
        }
        if (current != null && current.getRole() == UserRole.HEAD_NURSING) {
            if (!NursingBlockClassifier.matches(target)) {
                throw new ApiException(HttpStatus.FORBIDDEN,
                        "Chỉ xem được nhân sự khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa");
            }
            return;
        }
        if (isHeadRole(current)) {
            Long callerDept = requireHeadDepartmentId(current);
            Long targetDept = target.getDepartment() != null ? target.getDepartment().getId() : null;
            if (!callerDept.equals(targetDept)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ xem được nhân lực khoa của bạn");
            }
            String scopedUnit = resolveHeadWorkUnitScope(current);
            if (scopedUnit != null) {
                String targetUnit = employeeWorkforceDetailsRepository.findByEmployee(target)
                        .map(EmployeeWorkforceDetails::getWorkUnitDetail)
                        .map(String::trim)
                        .orElse("");
                if (!scopedUnit.equalsIgnoreCase(targetUnit)) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ xem được nhân lực bộ phận của bạn");
                }
            }
            return;
        }
        linkedSelf.ifPresentOrElse(self -> {
            if (self.getId().equals(target.getId())) {
                return;
            }
            throw new ApiException(HttpStatus.FORBIDDEN, "Chỉ xem được hồ sơ trong phạm vi được phân quyền");
        }, () -> {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền");
        });
    }

    /**
     * @return id phòng ban bắt buộc lọc khi caller là trưởng khoa/ĐDT; null nếu không phải trưởng.
     */
    public Long resolveHeadDepartmentScope(UserAccount caller) {
        if (caller == null || !isHeadRole(caller)) {
            return null;
        }
        return requireHeadDepartmentId(caller);
    }

    /**
     * @return tên bộ phận bắt buộc khi trưởng được đánh dấu "Trưởng bộ phận"; null = cả khoa.
     */
    public String resolveHeadWorkUnitScope(UserAccount caller) {
        if (caller == null || !isHeadRole(caller) || !caller.isWorkUnitScoped()) {
            return null;
        }
        Employee self = employeeLinkService.findLinkedEmployee(caller)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN,
                        "Tài khoản trưởng bộ phận cần gắn hồ sơ nhân viên"));
        return employeeWorkforceDetailsRepository.findByEmployee(self)
                .map(EmployeeWorkforceDetails::getWorkUnitDetail)
                .map(String::trim)
                .filter(s -> !s.isBlank())
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN,
                        "Hồ sơ trưởng bộ phận chưa có bộ phận — không thể xác định phạm vi"));
    }

    /** true nếu NV thuộc bộ phận (so khớp không phân biệt hoa thường); scopedUnit null → luôn true. */
    public boolean matchesWorkUnit(Employee emp, String scopedUnit) {
        if (scopedUnit == null || scopedUnit.isBlank()) {
            return true;
        }
        String targetUnit = employeeWorkforceDetailsRepository.findByEmployee(emp)
                .map(EmployeeWorkforceDetails::getWorkUnitDetail)
                .map(String::trim)
                .orElse("");
        return scopedUnit.trim().equalsIgnoreCase(targetUnit);
    }

    /**
     * Phạm vi xem hàng đợi HCNS 2 / toàn viện.
     * HEAD_HR dùng quyền HCNS 2 (toàn viện), không bị khóa khoa như trưởng khoa thường.
     */
    public boolean matchesHrReviewScope(UserAccount caller, Employee target) {
        if (caller == null) {
            return false;
        }
        if (caller.getRole() == UserRole.ADMIN
                || caller.getRole() == UserRole.DIRECTOR
                || isHr2Role(caller)) {
            return true;
        }
        return matchesHeadScope(caller, target);
    }

    /**
     * Kiểm tra nhân viên có thuộc phạm vi bắt buộc của trưởng khoa/bộ phận hay không.
     * Trưởng khoa xem cả khoa; tài khoản workUnitScoped chỉ xem đúng bộ phận trong khoa.
     */
    public boolean matchesHeadScope(UserAccount caller, Employee target) {
        if (!isHeadRole(caller)) {
            return true;
        }
        Long departmentId = resolveHeadDepartmentScope(caller);
        Long targetDepartmentId = target != null && target.getDepartment() != null
                ? target.getDepartment().getId() : null;
        if (departmentId != null && !departmentId.equals(targetDepartmentId)) {
            return false;
        }
        return matchesWorkUnit(target, resolveHeadWorkUnitScope(caller));
    }

    /**
     * ADMIN hoặc trưởng khoa/bộ phận có phạm vi khớp nhân viên → được nhận thông báo chờ duyệt
     * (trưởng bộ phận chỉ nhận đơn đúng bộ phận mình xử lý). Không ném lỗi nếu TK cấu hình thiếu.
     */
    public boolean shouldReceiveHeadPendingNotification(UserAccount account, Employee employee) {
        if (account == null || !account.isEnabled() || employee == null) {
            return false;
        }
        if (account.getRole() == UserRole.ADMIN) {
            return true;
        }
        if (!isHeadRole(account)) {
            return false;
        }
        try {
            return matchesHeadScope(account, employee);
        } catch (ApiException ex) {
            return false;
        }
    }

    /**
     * Phạm vi xem/duyệt của HEAD_NURSING: chỉ nhân sự khối ĐD–KTV–HS–Thư ký y khoa.
     * ADMIN luôn khớp; bản thân luôn khớp.
     */
    public boolean matchesNursingBlockScope(UserAccount caller, Employee target) {
        if (caller == null || target == null) {
            return false;
        }
        if (caller.getRole() == UserRole.ADMIN) {
            return true;
        }
        if (caller.getRole() != UserRole.HEAD_NURSING) {
            return false;
        }
        Long selfId = linkedEmployee(caller).map(Employee::getId).orElse(null);
        if (selfId != null && selfId.equals(target.getId())) {
            return true;
        }
        return NursingBlockClassifier.matches(target);
    }

    /** ADMIN / HEAD_NURSING được nhận thông báo chờ duyệt bước Trưởng phòng Điều dưỡng. */
    public boolean shouldReceiveNursingHeadPendingNotification(UserAccount account, Employee employee) {
        if (account == null || !account.isEnabled() || employee == null) {
            return false;
        }
        if (account.getRole() == UserRole.ADMIN) {
            return true;
        }
        if (account.getRole() != UserRole.HEAD_NURSING) {
            return false;
        }
        return NursingBlockClassifier.matches(employee);
    }

    private Long requireHeadDepartmentId(UserAccount head) {
        Employee self = employeeLinkService.findLinkedEmployee(head)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN,
                        "Tài khoản trưởng khoa/ĐDT cần gắn hồ sơ nhân viên để giới hạn theo khoa"));
        if (self.getDepartment() == null || self.getDepartment().getId() == null) {
            throw new ApiException(HttpStatus.FORBIDDEN,
                    "Hồ sơ trưởng khoa/ĐDT chưa có phòng ban — không thể xác định phạm vi khoa");
        }
        return self.getDepartment().getId();
    }

    public static boolean isHeadRole(UserAccount u) {
        return u != null && u.getRole() != null && u.getRole().isHeadDepartment();
    }

    public static boolean isHr2Role(UserAccount u) {
        return u != null && u.getRole() != null && u.getRole().isHr2();
    }

    /** ADMIN / HR / DIRECTOR xem toàn bệnh viện. */
    public static boolean canViewHospitalWide(UserAccount u) {
        return u != null && (u.getRole() == UserRole.ADMIN
                || u.getRole() == UserRole.HR
                || u.getRole() == UserRole.DIRECTOR);
    }

    /** Có quyền xem danh sách nhân sự rộng hơn bản thân (toàn viện hoặc theo khoa / khối ĐD). */
    public static boolean canViewAnyEmployee(UserAccount u) {
        return canViewHospitalWide(u) || isHr2Role(u) || isHeadRole(u)
                || (u != null && u.getRole() == UserRole.HEAD_NURSING);
    }

    /**
     * Đổi vai trò trên form HRM → cập nhật UserAppRoles trên sso_db (khớp LoginPhone).
     * Không chặn lưu HRM nếu SSO không có SĐT tương ứng.
     */
    private void syncHrmRoleToSso(String phone, String username, UserRole role) {
        SsoRoleService sso = ssoRoleService.getIfAvailable();
        if (sso == null || role == null) {
            return;
        }
        String key = (phone != null && !phone.isBlank()) ? phone.trim() : (username != null ? username.trim() : null);
        if (key == null || key.isBlank()) {
            log.warn("Bỏ qua sync SSO role — thiếu SĐT/username (role={})", role);
            return;
        }
        try {
            sso.assignHrmRoleByLoginPhone(key, role.name());
            log.info("Đã sync role SSO HRM={} theo SĐT/username={}", role, key);
        } catch (Exception ex) {
            log.warn("Không sync được role SSO cho {} → {}: {}", key, role, ex.getMessage());
        }
    }

    @Transactional(readOnly = true)
    public Optional<Employee> linkedEmployee(UserAccount user) {
        return employeeLinkService.findLinkedEmployee(user);
    }

    @Transactional(readOnly = true)
    public Optional<Employee> linkedEmployee() {
        return linkedEmployee(currentUser());
    }

    @Transactional(readOnly = true)
    public Employee requireLinkedEmployee() {
        return linkedEmployee()
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "Tài khoản chưa gắn hồ sơ nhân viên"));
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
