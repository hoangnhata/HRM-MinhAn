package com.minhan.hrm.controller;

import com.minhan.hrm.dto.account.AccountMeResponse;
import com.minhan.hrm.dto.account.AccountProfileUpdateRequest;
import com.minhan.hrm.dto.account.AvatarSaveRequest;
import com.minhan.hrm.dto.account.ChangePasswordRequest;
import com.minhan.hrm.dto.account.SignatureSaveRequest;
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
    @Operation(summary = "Ảnh đại diện (local ưu tiên, fallback ERP)")
    public ResponseEntity<byte[]> avatar() {
        ErpAuthClient.AvatarBytes avatar = accountService.getMyAvatar();
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-store, no-cache, must-revalidate")
                .header(HttpHeaders.PRAGMA, "no-cache")
                .header("Vary", "Authorization")
                .contentType(MediaType.parseMediaType(avatar.contentType()))
                .body(avatar.data());
    }

    @PutMapping("/me/avatar")
    @Operation(summary = "Tải lên / cập nhật ảnh đại diện (PNG/JPG base64)")
    public AccountMeResponse saveAvatar(@Valid @RequestBody AvatarSaveRequest request) {
        return accountService.saveMyAvatar(request);
    }

    @DeleteMapping("/me/avatar")
    @Operation(summary = "Xóa ảnh đại diện local")
    public AccountMeResponse deleteAvatar() {
        return accountService.deleteMyAvatar();
    }

    @GetMapping("/me/signature")
    @Operation(summary = "Ảnh chữ ký số cá nhân của tài khoản đang đăng nhập")
    public ResponseEntity<byte[]> mySignature() {
        AccountService.SignatureBytes sig = accountService.getMySignature();
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-store, no-cache, must-revalidate")
                .header(HttpHeaders.PRAGMA, "no-cache")
                .contentType(MediaType.parseMediaType(sig.contentType()))
                .body(sig.data());
    }

    @PutMapping("/me/signature")
    @Operation(summary = "Tạo / cập nhật chữ ký số cá nhân (ảnh PNG/JPG base64)")
    public AccountMeResponse saveSignature(@Valid @RequestBody SignatureSaveRequest request) {
        return accountService.saveMySignature(request);
    }

    @DeleteMapping("/me/signature")
    @Operation(summary = "Xóa chữ ký số cá nhân")
    public AccountMeResponse deleteSignature() {
        return accountService.deleteMySignature();
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
