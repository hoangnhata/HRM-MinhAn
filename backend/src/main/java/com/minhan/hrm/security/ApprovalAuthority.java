package com.minhan.hrm.security;

import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;

public final class ApprovalAuthority {
    private ApprovalAuthority() {
    }

    public static boolean isDirectorApprover(UserAccount user) {
        return user != null
                && user.isEnabled()
            && (user.getRole() == UserRole.ADMIN || user.isDirectorApprovalEnabled());
    }
}
