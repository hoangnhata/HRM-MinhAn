package com.minhan.hrm.controller;

import com.minhan.hrm.dto.account.AccountMeResponse;
import com.minhan.hrm.dto.account.AccountProfileUpdateRequest;
import com.minhan.hrm.dto.account.ChangePasswordRequest;
import com.minhan.hrm.service.AccountService;
import com.minhan.hrm.sso.ErpAuthClient;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/j1-api/v1/account")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Account", description = "Tài khoản đăng nhập")
public class AccountController {

    private final AccountService accountService;

    @GetMapping("/me")
    @Operation(summary = "Thông tin tài khoản + hồ sơ ERP (vai trò luôn theo HRM)")
    public AccountMeResponse me() {
        return accountService.getMe();
    }

    @GetMapping("/me/avatar")
    @Operation(summary = "Ảnh đại diện từ ERP (proxy)")
    public ResponseEntity<byte[]> avatar() {
        ErpAuthClient.AvatarBytes avatar = accountService.getErpAvatar();
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-store, no-cache, must-revalidate")
                .header(HttpHeaders.PRAGMA, "no-cache")
                .header("Vary", "Authorization")
                .contentType(MediaType.parseMediaType(avatar.contentType()))
                .body(avatar.data());
    }

    @PatchMapping("/me")
    @Operation(summary = "Cập nhật hồ sơ (ERP nếu đã liên kết; phòng ban/vai trò theo HRM)")
    public AccountMeResponse updateMe(@Valid @RequestBody AccountProfileUpdateRequest request) {
        return accountService.updateProfile(request);
    }

    @PostMapping("/change-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Đổi mật khẩu")
    public void changePassword(@Valid @RequestBody ChangePasswordRequest request) {
        accountService.changePassword(request);
    }
}
