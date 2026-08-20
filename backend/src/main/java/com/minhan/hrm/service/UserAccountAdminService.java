package com.minhan.hrm.service;

import com.minhan.hrm.account.EmployeeAccountProvisioner;
import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.dto.account.EmployeeWithoutAccountDto;
import com.minhan.hrm.dto.account.LocalAccountGrantRequest;
import com.minhan.hrm.dto.account.UserAccountAdminDto;
import com.minhan.hrm.dto.account.UserAccountIdentifiersUpdateRequest;
import com.minhan.hrm.dto.account.UserAccountRoleUpdateRequest;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Quản trị tài khoản đăng nhập local (MySQL users) — không phụ thuộc SSO.
 */
@Service
@RequiredArgsConstructor
public class UserAccountAdminService {

    private final UserAccountRepository userAccountRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;
    private final EmployeeAccountProvisioner accountProvisioner;
    private final PasswordEncoder passwordEncoder;
    private final HrmProperties hrmProperties;
    private final EmployeeService employeeService;

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    public Page<UserAccountAdminDto> list(
            String q,
            Long departmentId,
            String workUnitDetail,
            UserRole role,
            Boolean inactiveOnly,
            Pageable pageable) {
        String needle = q != null ? q.trim().toLowerCase(Locale.ROOT) : "";
        String unitNeedle = workUnitDetail != null ? workUnitDetail.trim() : "";
        boolean onlyInactive = Boolean.TRUE.equals(inactiveOnly);
        List<UserAccount> users = userAccountRepository.findAll();
        Map<Long, Employee> empByUserId = employeeRepository.findAll().stream()
                .filter(e -> e.getUser() != null)
                .collect(Collectors.toMap(e -> e.getUser().getId(), Function.identity(), (a, b) -> a));
        Map<Long, EmployeeWorkforceDetails> wfByEmpId = workforceDetailsRepository
                .findByEmployeeIn(new ArrayList<>(empByUserId.values())).stream()
                .collect(Collectors.toMap(EmployeeWorkforceDetails::getEmployeeId, Function.identity(), (a, b) -> a));

        List<UserAccountAdminDto> all = new ArrayList<>();
        for (UserAccount u : users) {
            Employee emp = empByUserId.get(u.getId());
            EmployeeWorkforceDetails wf = emp != null ? wfByEmpId.get(emp.getId()) : null;
            UserAccountAdminDto dto = toDto(u, emp, wf);
            if (onlyInactive) {
                // Chưa kích hoạt: chưa đổi mật khẩu hoặc chưa có chữ ký
                if (!dto.isMustChangePassword() && dto.isHasSignature()) {
                    continue;
                }
            }
            if (role != null && (dto.getRole() == null || !role.name().equals(dto.getRole()))) {
                continue;
            }
            if (departmentId != null) {
                if (dto.getDepartmentId() == null || !departmentId.equals(dto.getDepartmentId())) {
                    continue;
                }
            }
            if (!unitNeedle.isEmpty()) {
                if (dto.getWorkUnitDetail() == null || !unitNeedle.equalsIgnoreCase(dto.getWorkUnitDetail().trim())) {
                    continue;
                }
            }
            if (!needle.isEmpty()) {
                String hay = String.join(" ",
                        nullToEmpty(dto.getUsername()),
                        nullToEmpty(dto.getFullName()),
                        nullToEmpty(dto.getEmail()),
                        nullToEmpty(dto.getDepartmentName()),
                        nullToEmpty(dto.getWorkUnitDetail()),
                        nullToEmpty(dto.getEmployeeCode()),
                        nullToEmpty(dto.getPhone()),
                        nullToEmpty(dto.getAttendanceCode())).toLowerCase(Locale.ROOT);
                if (!hay.contains(needle)) {
                    continue;
                }
            }
            all.add(dto);
        }
        all.sort(Comparator.comparing(UserAccountAdminDto::getUsername, Comparator.nullsLast(String::compareToIgnoreCase)));
        return paginate(all, pageable);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    public Page<EmployeeWithoutAccountDto> listWithoutAccount(
            String q, Long departmentId, String workUnitDetail, Pageable pageable) {
        String needle = q != null ? q.trim().toLowerCase(Locale.ROOT) : "";
        String unitNeedle = workUnitDetail != null ? workUnitDetail.trim() : "";
        List<Employee> employees = employeeRepository.findAll();
        Map<Long, EmployeeWorkforceDetails> wfByEmpId = workforceDetailsRepository
                .findByEmployeeIn(employees).stream()
                .collect(Collectors.toMap(EmployeeWorkforceDetails::getEmployeeId, Function.identity(), (a, b) -> a));

        List<EmployeeWithoutAccountDto> all = new ArrayList<>();
        for (Employee emp : employees) {
            // employees.user_id NOT NULL — "chưa có tài khoản đăng nhập" = thiếu SĐT (username đăng nhập)
            // hoặc thiếu mã chấm công (chưa đủ để dùng hệ thống chấm công).
            EmployeeWorkforceDetails wf = wfByEmpId.get(emp.getId());
            boolean missingPhone = emp.getPhone() == null || emp.getPhone().isBlank();
            String attendance = wf != null ? wf.getAttendanceCode() : null;
            boolean missingAttendance = attendance == null || attendance.isBlank();
            if (!missingPhone && !missingAttendance) {
                continue;
            }
            // Bỏ NV đã nghỉ việc khỏi hàng đợi cấp tài khoản
            if (emp.getStatus() == EmployeeStatus.TERMINATED) {
                continue;
            }
            EmployeeWithoutAccountDto dto = toWithoutAccountDto(emp, wf);
            if (departmentId != null) {
                if (dto.getDepartmentId() == null || !departmentId.equals(dto.getDepartmentId())) {
                    continue;
                }
            }
            if (!unitNeedle.isEmpty()) {
                if (dto.getWorkUnitDetail() == null || !unitNeedle.equalsIgnoreCase(dto.getWorkUnitDetail().trim())) {
                    continue;
                }
            }
            if (!needle.isEmpty()) {
                String hay = String.join(" ",
                        nullToEmpty(dto.getFullName()),
                        nullToEmpty(dto.getEmployeeCode()),
                        nullToEmpty(dto.getDepartmentName()),
                        nullToEmpty(dto.getWorkUnitDetail()),
                        nullToEmpty(dto.getPhone()),
                        nullToEmpty(dto.getAttendanceCode())).toLowerCase(Locale.ROOT);
                if (!hay.contains(needle)) {
                    continue;
                }
            }
            all.add(dto);
        }
        all.sort(Comparator.comparing(EmployeeWithoutAccountDto::getFullName, Comparator.nullsLast(String::compareToIgnoreCase)));
        return paginate(all, pageable);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserAccountAdminDto updateRole(Long userId, UserAccountRoleUpdateRequest req) {
        UserAccount actor = employeeService.currentUser();
        UserAccount target = userAccountRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"));
        if (actor.getId().equals(target.getId()) && req.getRole() != UserRole.ADMIN) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không thể tự bỏ quyền ADMIN của chính mình");
        }
        if (target.getRole() == UserRole.ADMIN && req.getRole() != UserRole.ADMIN
                && userAccountRepository.countByRole(UserRole.ADMIN) <= 1) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phải còn ít nhất một tài khoản ADMIN");
        }
        target.setRole(req.getRole());
        if (req.getRole() != UserRole.DIRECTOR) {
            target.setDirectorApprovalEnabled(false);
        }
        if (req.getRole() == null || !req.getRole().isHeadDepartment()) {
            target.setWorkUnitScoped(false);
        }
        userAccountRepository.save(target);
        Employee emp = employeeRepository.findByUser(target).orElse(null);
        EmployeeWorkforceDetails wf = emp != null
                ? workforceDetailsRepository.findByEmployee(emp).orElse(null) : null;
        return toDto(target, emp, wf);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserAccountAdminDto updateIdentifiers(Long userId, UserAccountIdentifiersUpdateRequest req) {
        UserAccount target = userAccountRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"));
        Employee emp = employeeRepository.findByUser(target)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "Tài khoản chưa được gắn với hồ sơ nhân viên"));
        if (req.getPhone() == null && req.getAttendanceCode() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không có thông tin cần cập nhật");
        }

        employeeService.updateAccountIdentifiers(emp, req.getPhone(), req.getAttendanceCode());
        EmployeeWorkforceDetails wf = workforceDetailsRepository.findByEmployee(emp).orElse(null);
        return toDto(target, emp, wf);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserAccountAdminDto setEnabled(Long userId, boolean enabled) {
        UserAccount actor = employeeService.currentUser();
        UserAccount target = userAccountRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"));
        if (actor.getId().equals(target.getId()) && !enabled) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không thể tự khóa tài khoản của mình");
        }
        if (target.getRole() == UserRole.ADMIN && !enabled
                && userAccountRepository.countByRole(UserRole.ADMIN) <= 1) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không khóa ADMIN cuối cùng");
        }
        target.setEnabled(enabled);
        userAccountRepository.save(target);
        Employee emp = employeeRepository.findByUser(target).orElse(null);
        return toDto(target, emp, emp != null ? workforceDetailsRepository.findByEmployee(emp).orElse(null) : null);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserAccountAdminDto setDirectorApprovalEnabled(Long userId, boolean enabled) {
        UserAccount target = userAccountRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"));
        if (target.getRole() != UserRole.DIRECTOR) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Chỉ tài khoản có vai trò Giám đốc mới được bật quyền duyệt đơn");
        }
        target.setDirectorApprovalEnabled(enabled);
        userAccountRepository.save(target);
        Employee emp = employeeRepository.findByUser(target).orElse(null);
        return toDto(target, emp,
                emp != null ? workforceDetailsRepository.findByEmployee(emp).orElse(null) : null);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserAccountAdminDto setReportViewEnabled(Long userId, boolean enabled) {
        UserAccount target = userAccountRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"));
        target.setReportViewEnabled(enabled);
        userAccountRepository.save(target);
        Employee emp = employeeRepository.findByUser(target).orElse(null);
        return toDto(target, emp,
                emp != null ? workforceDetailsRepository.findByEmployee(emp).orElse(null) : null);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserAccountAdminDto setWorkUnitScoped(Long userId, boolean enabled) {
        UserAccount target = userAccountRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"));
        if (target.getRole() == null || !target.getRole().isHeadDepartment()) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Chỉ tài khoản Trưởng khoa / phòng mới được đánh dấu Trưởng bộ phận");
        }
        if (enabled) {
            Employee emp = employeeRepository.findByUser(target)
                    .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST,
                            "Tài khoản chưa gắn hồ sơ nhân viên — không thể bật Trưởng bộ phận"));
            String unit = workforceDetailsRepository.findByEmployee(emp)
                    .map(EmployeeWorkforceDetails::getWorkUnitDetail)
                    .map(String::trim)
                    .filter(s -> !s.isBlank())
                    .orElse(null);
            if (unit == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Hồ sơ chưa có bộ phận — bổ sung bộ phận trước khi bật Trưởng bộ phận");
            }
        }
        target.setWorkUnitScoped(enabled);
        userAccountRepository.save(target);
        Employee emp = employeeRepository.findByUser(target).orElse(null);
        return toDto(target, emp,
                emp != null ? workforceDetailsRepository.findByEmployee(emp).orElse(null) : null);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserAccountAdminDto resetPassword(Long userId) {
        UserAccount target = userAccountRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"));
        String raw = hrmProperties.getImportConfig().getDefaultEmployeePassword();
        target.setPasswordHash(passwordEncoder.encode(raw));
        target.setMustChangePassword(true);
        userAccountRepository.save(target);
        Employee emp = employeeRepository.findByUser(target).orElse(null);
        return toDto(target, emp, emp != null ? workforceDetailsRepository.findByEmployee(emp).orElse(null) : null);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public UserAccountAdminDto grant(LocalAccountGrantRequest req) {
        Employee emp = employeeRepository.findById(req.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhân viên"));

        String phoneRaw = req.getPhone() != null && !req.getPhone().isBlank()
                ? req.getPhone().trim()
                : emp.getPhone();
        String phoneNorm = accountProvisioner.normalizePhoneUsername(phoneRaw);
        if (phoneNorm == null || phoneNorm.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cần số điện thoại để cấp tài khoản đăng nhập");
        }

        // SĐT trùng NV khác?
        for (Employee other : employeeRepository.findByPhoneEndingWith(
                phoneNorm.length() >= 9 ? phoneNorm.substring(phoneNorm.length() - 9) : phoneNorm)) {
            if (!other.getId().equals(emp.getId())) {
                String otherNorm = accountProvisioner.normalizePhoneUsername(other.getPhone());
                if (phoneNorm.equals(otherNorm)) {
                    throw new ApiException(HttpStatus.CONFLICT, "Số điện thoại đã gắn với nhân viên khác");
                }
            }
        }
        emp.setPhone(phoneNorm);

        String attendance = req.getAttendanceCode() != null ? req.getAttendanceCode().trim() : "";
        EmployeeWorkforceDetails wf = workforceDetailsRepository.findByEmployee(emp)
                .orElseGet(() -> EmployeeWorkforceDetails.builder().employee(emp).build());
        if (!attendance.isEmpty()) {
            workforceDetailsRepository.findByAttendanceCode(attendance).ifPresent(other -> {
                if (!Objects.equals(other.getEmployeeId(), emp.getId())) {
                    throw new ApiException(HttpStatus.CONFLICT, "Mã chấm công đã được dùng bởi nhân viên khác");
                }
            });
            wf.setAttendanceCode(attendance);
        }
        if (wf.getEmployee() == null) {
            wf.setEmployee(emp);
        }
        workforceDetailsRepository.save(wf);

        UserRole role = req.getRole() != null
                ? req.getRole()
                : accountProvisioner.resolveImportRole(emp.getDepartment(), emp.getPosition());
        String email = phoneNorm + "@minhan.local";
        String rawPassword = req.getPassword() != null && !req.getPassword().isBlank()
                ? req.getPassword().trim()
                : hrmProperties.getImportConfig().getDefaultEmployeePassword();

        UserAccount user = emp.getUser();
        if (user == null) {
            // Schema hiện tại bắt buộc user_id — phòng khi dữ liệu lệch
            user = accountProvisioner.buildNewEmployeeUser(phoneNorm, emp.getEmployeeCode(), email, role);
            user.setDisplayName(emp.getFullName());
            user.setPasswordHash(passwordEncoder.encode(rawPassword));
            user.setMustChangePassword(true);
            user = userAccountRepository.save(user);
            emp.setUser(user);
        } else {
            // Đổi username sang SĐT nếu chưa trùng user khác
            if (!phoneNorm.equals(user.getUsername())) {
                if (userAccountRepository.existsByUsername(phoneNorm)
                        && !phoneNorm.equalsIgnoreCase(user.getUsername())) {
                    // username đã có — giữ username hiện tại nếu là cùng user; nếu khác thì lỗi
                    UserAccount taken = userAccountRepository.findByUsername(phoneNorm).orElse(null);
                    if (taken != null && !taken.getId().equals(user.getId())) {
                        throw new ApiException(HttpStatus.CONFLICT,
                                "SĐT đã là username của tài khoản khác");
                    }
                } else {
                    user.setUsername(phoneNorm);
                }
            }
            user.setEmail(email);
            user.setDisplayName(emp.getFullName());
            user.setRole(role);
            user.setEnabled(true);
            user.setPasswordHash(passwordEncoder.encode(rawPassword));
            user.setMustChangePassword(true);
            user = userAccountRepository.save(user);
        }
        employeeRepository.save(emp);
        return toDto(user, emp, wf);
    }

    private static UserAccountAdminDto toDto(UserAccount u, Employee emp, EmployeeWorkforceDetails wf) {
        return UserAccountAdminDto.builder()
                .userId(u.getId())
                .username(u.getUsername())
                .email(u.getEmail())
                .displayName(u.getDisplayName())
                .role(u.getRole() != null ? u.getRole().name() : null)
                .enabled(u.isEnabled())
                .directorApprovalEnabled(u.isDirectorApprovalEnabled())
                .reportViewEnabled(u.isReportViewEnabled())
                .workUnitScoped(u.isWorkUnitScoped())
                .mustChangePassword(u.isMustChangePassword())
                .hasSignature(u.getSignaturePath() != null && !u.getSignaturePath().isBlank())
                .employeeId(emp != null ? emp.getId() : null)
                .employeeCode(emp != null ? emp.getEmployeeCode() : null)
                .fullName(emp != null ? emp.getFullName() : u.getDisplayName())
                .phone(emp != null ? emp.getPhone() : null)
                .attendanceCode(wf != null ? wf.getAttendanceCode() : null)
                .departmentId(emp != null && emp.getDepartment() != null ? emp.getDepartment().getId() : null)
                .departmentName(emp != null && emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                .workUnitDetail(wf != null ? wf.getWorkUnitDetail() : null)
                .positionTitle(emp != null && emp.getPosition() != null ? emp.getPosition().getTitle() : null)
                .build();
    }

    private static EmployeeWithoutAccountDto toWithoutAccountDto(Employee emp, EmployeeWorkforceDetails wf) {
        String phone = emp.getPhone();
        String attendance = wf != null ? wf.getAttendanceCode() : null;
        return EmployeeWithoutAccountDto.builder()
                .employeeId(emp.getId())
                .employeeCode(emp.getEmployeeCode())
                .fullName(emp.getFullName())
                .phone(phone)
                .attendanceCode(attendance)
                .departmentId(emp.getDepartment() != null ? emp.getDepartment().getId() : null)
                .departmentName(emp.getDepartment() != null ? emp.getDepartment().getName() : null)
                .workUnitDetail(wf != null ? wf.getWorkUnitDetail() : null)
                .positionTitle(emp.getPosition() != null ? emp.getPosition().getTitle() : null)
                .status(emp.getStatus() != null ? emp.getStatus().name() : null)
                .missingPhone(phone == null || phone.isBlank())
                .missingAttendanceCode(attendance == null || attendance.isBlank())
                .build();
    }

    private static <T> Page<T> paginate(List<T> all, Pageable pageable) {
        int start = (int) pageable.getOffset();
        if (start >= all.size()) {
            return new PageImpl<>(List.of(), pageable, all.size());
        }
        int end = Math.min(start + pageable.getPageSize(), all.size());
        return new PageImpl<>(all.subList(start, end), pageable, all.size());
    }

    private static String nullToEmpty(String s) {
        return s != null ? s : "";
    }
}
