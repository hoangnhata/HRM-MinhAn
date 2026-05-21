package com.minhan.hrm.controller;

import com.minhan.hrm.dto.account.AccountMeResponse;
import com.minhan.hrm.dto.account.AccountProfileUpdateRequest;
import com.minhan.hrm.dto.account.ChangePasswordRequest;
import com.minhan.hrm.service.AccountService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/account")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Account", description = "Tài khoản đăng nhập")
public class AccountController {

    private final AccountService accountService;

    @GetMapping("/me")
    @Operation(summary = "Thông tin tài khoản hiện tại")
    public AccountMeResponse me() {
        return accountService.getMe();
    }

    @PatchMapping("/me")
    @Operation(summary = "Cập nhật email / liên hệ (NV tự sửa phần liên hệ)")
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
