package com.minhan.hrm.security;

import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserAccountRepository userAccountRepository;

    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        UserAccount u = userAccountRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("Không tìm thấy người dùng"));
        List<SimpleGrantedAuthority> authorities = new ArrayList<>();
        if (u.getRole() == com.minhan.hrm.entity.UserRole.DIRECTOR) {
            // Giám đốc: xem công cá nhân (EMPLOYEE) + quyền báo cáo / duyệt (DIRECTOR)
            authorities.add(new SimpleGrantedAuthority("ROLE_EMPLOYEE"));
            authorities.add(new SimpleGrantedAuthority("ROLE_DIRECTOR"));
        } else {
            authorities.add(new SimpleGrantedAuthority("ROLE_" + u.getRole().name()));
            if (u.getRole() == com.minhan.hrm.entity.UserRole.HEAD_HR) {
                // Trưởng phòng HCNS = trưởng khoa/phòng + HCNS 2
                authorities.add(new SimpleGrantedAuthority("ROLE_HEAD_DEPARTMENT"));
                authorities.add(new SimpleGrantedAuthority("ROLE_HR2"));
                authorities.add(new SimpleGrantedAuthority("ROLE_EMPLOYEE"));
            } else if (u.getRole() == com.minhan.hrm.entity.UserRole.HR
                    || u.getRole() == com.minhan.hrm.entity.UserRole.HR2) {
                authorities.add(new SimpleGrantedAuthority("ROLE_EMPLOYEE"));
            }
            // Tài khoản khác được bật duyệt Giám đốc
            if (u.isDirectorApprovalEnabled()) {
                authorities.add(new SimpleGrantedAuthority("ROLE_DIRECTOR"));
            }
        }
        if (u.isReportViewEnabled()) {
            authorities.add(new SimpleGrantedAuthority("ROLE_REPORT_VIEWER"));
        }
        return User.builder()
                .username(u.getUsername())
                .password(u.getPasswordHash())
                .disabled(!u.isEnabled())
                .authorities(authorities)
                .build();
    }
}
