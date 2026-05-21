package com.minhan.hrm.service;

import com.minhan.hrm.dto.auth.LoginRequest;
import com.minhan.hrm.dto.auth.LoginResponse;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.security.CustomUserDetailsService;
import com.minhan.hrm.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeRepository employeeRepository;
    private final CustomUserDetailsService userDetailsService;
    private final JwtService jwtService;

    @Transactional(readOnly = true)
    public LoginResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword()));

        UserAccount user = userAccountRepository.findByUsername(request.getUsername())
                .orElseThrow();
        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getUsername());
        String token = jwtService.generateToken(userDetails, user.getId(), user.getRole().name());

        Long employeeId = null;
        String fullName = user.getUsername();
        var empOpt = employeeRepository.findByUser(user);
        if (empOpt.isPresent()) {
            Employee e = empOpt.get();
            employeeId = e.getId();
            fullName = e.getFullName();
        }

        return LoginResponse.builder()
                .accessToken(token)
                .tokenType("Bearer")
                .role(user.getRole())
                .userId(user.getId())
                .employeeId(employeeId)
                .fullName(fullName)
                .email(user.getEmail())
                .build();
    }
}
