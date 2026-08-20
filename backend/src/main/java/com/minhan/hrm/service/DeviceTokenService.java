package com.minhan.hrm.service;

import com.minhan.hrm.dto.device.DeviceTokenRegisterRequest;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserDeviceToken;
import com.minhan.hrm.repository.UserDeviceTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DeviceTokenService {

    private final UserDeviceTokenRepository deviceTokenRepository;
    private final EmployeeService employeeService;

    @Transactional
    public void register(DeviceTokenRegisterRequest req) {
        UserAccount user = employeeService.currentUser();
        String token = req.getToken().trim();
        String platform = req.getPlatform() == null || req.getPlatform().isBlank()
                ? "ANDROID"
                : req.getPlatform().trim().toUpperCase();

        UserDeviceToken row = deviceTokenRepository.findByToken(token).orElse(null);
        if (row == null) {
            deviceTokenRepository.save(UserDeviceToken.builder()
                    .user(user)
                    .token(token)
                    .platform(platform)
                    .build());
            return;
        }
        row.setUser(user);
        row.setPlatform(platform);
        deviceTokenRepository.save(row);
    }

    @Transactional
    public void unregister(String token) {
        if (token == null || token.isBlank()) {
            return;
        }
        UserAccount user = employeeService.currentUser();
        deviceTokenRepository.deleteByUserAndToken(user, token.trim());
    }

    @Transactional
    public void unregisterAllForCurrentUser() {
        UserAccount user = employeeService.currentUser();
        deviceTokenRepository.findByUser(user).forEach(deviceTokenRepository::delete);
    }
}
