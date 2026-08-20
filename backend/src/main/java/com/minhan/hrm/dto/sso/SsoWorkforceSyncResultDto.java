package com.minhan.hrm.dto.sso;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class SsoWorkforceSyncResultDto {
    private int scanned;
    private int accountsCreated;
    private int accountsUpdated;
    private int accountsDeactivated;
    /** Số TK trùng SĐT bị xóa (giữ bản HRM mới). */
    private int duplicatesMerged;
    /** TK SSO không còn trong danh sách nhân lực HRM — đã xóa. */
    private int accountsOrphansRemoved;
    /** Hồ sơ public/private gắn mã chấm công không còn trong HRM — đã xóa. */
    private int profilesOrphansRemoved;
    private int publicUpserted;
    private int privateUpserted;
    /** Số phòng ban/bộ phận khớp sẵn trên RelationDept (chamcong). */
    private int relationDeptMatched;
    /** Số phòng ban/bộ phận mới tạo trên RelationDept. */
    private int relationDeptCreated;
    private int skippedNoPhone;
    private int skippedNoEnroll;
    /** Số hồ sơ HRM bị bỏ qua vì trùng SĐT với hồ sơ khác đã chọn. */
    private int skippedDuplicatePhone;
    private int failed;
    private String message;
}
