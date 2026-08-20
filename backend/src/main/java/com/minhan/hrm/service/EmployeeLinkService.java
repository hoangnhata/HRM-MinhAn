package com.minhan.hrm.service;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.util.PhoneLoginUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/**
 * Gắn tài khoản đăng nhập (SĐT SSO) với hồ sơ nhân viên HRM.
 * Hỗ trợ NV thử việc: user_id vẫn trỏ TV-* nhưng đăng nhập bằng SĐT.
 */
@Service
@RequiredArgsConstructor
public class EmployeeLinkService {

    private final EmployeeRepository employeeRepository;

    @Transactional(readOnly = true)
    public Optional<Employee> findLinkedEmployee(UserAccount user) {
        if (user == null) {
            return Optional.empty();
        }
        Optional<Employee> direct = employeeRepository.findByUser(user);
        if (direct.isPresent()) {
            return direct;
        }
        String login = PhoneLoginUtil.toLoginPhone(user.getUsername());
        String tail = PhoneLoginUtil.phoneLocal9(login != null ? login : user.getUsername());
        if (tail == null) {
            return Optional.empty();
        }
        List<Employee> matches = employeeRepository.findByPhoneEndingWith(tail);
        for (Employee e : matches) {
            String empTail = PhoneLoginUtil.phoneLocal9(PhoneLoginUtil.toLoginPhone(e.getPhone()));
            if (tail.equals(empTail)) {
                return Optional.of(e);
            }
        }
        return matches.stream().findFirst();
    }
}
