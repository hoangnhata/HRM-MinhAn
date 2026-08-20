package com.minhan.hrm.controller;

import com.minhan.hrm.dto.device.DeviceTokenRegisterRequest;
import com.minhan.hrm.dto.device.DeviceTokenUnregisterRequest;
import com.minhan.hrm.service.DeviceTokenService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/j1-api/v1/device-tokens")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Device tokens", description = "Đăng ký FCM token cho push mobile")
public class DeviceTokenController {

    private final DeviceTokenService deviceTokenService;

    @PostMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Đăng ký / cập nhật FCM device token")
    public void register(@Valid @RequestBody DeviceTokenRegisterRequest req) {
        deviceTokenService.register(req);
    }

    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Huỷ đăng ký FCM device token")
    public void unregister(@Valid @RequestBody DeviceTokenUnregisterRequest req) {
        deviceTokenService.unregister(req.getToken());
    }
}
