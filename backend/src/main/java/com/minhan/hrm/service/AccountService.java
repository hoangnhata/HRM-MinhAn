package com.minhan.hrm.service;

import com.minhan.hrm.dto.account.AccountMeResponse;
import com.minhan.hrm.dto.account.AccountProfileUpdateRequest;
import com.minhan.hrm.dto.account.ChangePasswordRequest;
import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AccountService {

    private final UserAccountRepository userAccountRepository;
    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional(readOnly = true)
    public AccountMeResponse getMe() {
        UserAccount u = currentUser();
        return buildMe(u);
    }

    @Transactional
    public AccountMeResponse updateProfile(AccountProfileUpdateRequest req) {
        UserAccount u = currentUser();
        if (req.getEmail() != null && !req.getEmail().isBlank()) {
            String em = req.getEmail().trim();
            if (!em.equalsIgnoreCase(u.getEmail())
                    && userAccountRepository.existsByEmailIgnoreCaseAndIdNot(em, u.getId())) {
                throw new ApiException(HttpStatus.CONFLICT, "Email đã được sử dụng");
            }
            u.setEmail(em);
            userAccountRepository.save(u);
        }
        employeeRepository.findByUser(u).ifPresent(e -> {
            boolean changed = false;
            if (req.getPhone() != null) {
                e.setPhone(req.getPhone().trim().isEmpty() ? null : req.getPhone().trim());
                changed = true;
            }
            if (req.getAddress() != null) {
                e.setAddress(req.getAddress().trim().isEmpty() ? null : req.getAddress().trim());
                changed = true;
            }
            if (req.getFullName() != null && !req.getFullName().isBlank()) {
                e.setFullName(req.getFullName().trim());
                changed = true;
            }
            if (req.getDepartmentId() != null) {
                Department d = departmentRepository
                        .findById(req.getDepartmentId())
                        .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "Phòng ban không tồn tại"));
                e.setDepartment(d);
                changed = true;
            }
            if (changed) {
                employeeRepository.save(e);
            }
        });
        return buildMe(userAccountRepository.findById(u.getId()).orElseThrow());
    }

    @Transactional
    public void changePassword(ChangePasswordRequest req) {
        UserAccount u = currentUser();
        if (!passwordEncoder.matches(req.getOldPassword(), u.getPasswordHash())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mật khẩu hiện tại không đúng");
        }
        u.setPasswordHash(passwordEncoder.encode(req.getNewPassword()));
        u.setMustChangePassword(false);
        userAccountRepository.save(u);
    }

    private UserAccount currentUser() {
        return userAccountRepository
                .findByUsername(SecurityUtils.currentUsername())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "Chưa đăng nhập"));
    }

    private AccountMeResponse buildMe(UserAccount u) {
        AccountMeResponse.AccountMeResponseBuilder b = AccountMeResponse.builder()
                .userId(u.getId())
                .username(u.getUsername())
                .email(u.getEmail())
                .role(u.getRole().name())
                .enabled(u.isEnabled())
                .mustChangePassword(u.isMustChangePassword())
                .createdAt(u.getCreatedAt().toString());
        return employeeRepository
                .findByUser(u)
                .map(e -> b.fullName(e.getFullName())
                        .employeeId(e.getId())
                        .phone(e.getPhone())
                        .address(e.getAddress())
                        .departmentName(e.getDepartment().getName())
                        .departmentId(e.getDepartment().getId())
                        .build())
                .orElseGet(() -> b.fullName(u.getUsername())
                        .employeeId(null)
                        .phone("")
                        .address("")
                        .departmentName(null)
                        .departmentId(null)
                        .build());
    }
}
