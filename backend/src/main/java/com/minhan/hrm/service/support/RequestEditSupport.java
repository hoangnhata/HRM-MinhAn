package com.minhan.hrm.service.support;

import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import org.springframework.http.HttpStatus;

/** Kiểm tra quyền chỉnh sửa đơn đang chờ duyệt (người lập hoặc ADMIN). */
public final class RequestEditSupport {

    private RequestEditSupport() {
    }

    public static void ensureRequesterOrAdmin(UserAccount actor, UserAccount requestedBy, String forbiddenMessage) {
        boolean can = actor.getRole() == UserRole.ADMIN
                || (requestedBy != null && requestedBy.getId().equals(actor.getId()));
        if (!can) {
            throw new ApiException(HttpStatus.FORBIDDEN, forbiddenMessage);
        }
    }

    public static void ensurePendingStatus(Enum<?> status, String entityLabel) {
        if (status == null || !status.name().startsWith("PENDING")) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Chỉ chỉnh sửa được " + entityLabel + " đang chờ duyệt");
        }
    }
}
