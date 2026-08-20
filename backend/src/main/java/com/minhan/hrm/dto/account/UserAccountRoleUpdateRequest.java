package com.minhan.hrm.dto.account;

import com.minhan.hrm.entity.UserRole;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UserAccountRoleUpdateRequest {
    @NotNull
    private UserRole role;
}
