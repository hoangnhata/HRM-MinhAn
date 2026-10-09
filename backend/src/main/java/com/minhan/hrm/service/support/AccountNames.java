package com.minhan.hrm.service.support;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;

/** Tên người hiển thị cho tài khoản (người lập / người duyệt) thay vì username — thường là SĐT. */
public final class AccountNames {

    private AccountNames() {}

    /** Họ tên hồ sơ nhân viên liên kết → tên hiển thị tài khoản → username. */
    public static String personName(UserAccount u) {
        if (u == null) {
            return null;
        }
        try {
            Employee linked = u.getEmployee();
            if (linked != null && linked.getFullName() != null && !linked.getFullName().isBlank()) {
                return linked.getFullName().trim();
            }
        } catch (Exception ignored) {
            // lazy load có thể fail ngoài session — fallback displayName/username
        }
        if (u.getDisplayName() != null && !u.getDisplayName().isBlank()) {
            return u.getDisplayName().trim();
        }
        return u.getUsername();
    }
}
