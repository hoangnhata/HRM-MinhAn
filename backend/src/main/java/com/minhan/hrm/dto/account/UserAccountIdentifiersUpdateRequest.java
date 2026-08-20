package com.minhan.hrm.dto.account;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UserAccountIdentifiersUpdateRequest {

    /** Chỉ gửi khi thực sự đổi SĐT. */
    private String phone;

    /** Chuỗi rỗng = xóa mã; null = không thay đổi. */
    private String attendanceCode;
}
