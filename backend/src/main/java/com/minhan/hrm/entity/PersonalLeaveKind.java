package com.minhan.hrm.entity;

/**
 * Chế độ nghỉ việc riêng theo Điều 115 Bộ luật Lao động 2019.
 *
 * Nhân viên chính thức nghỉ 3 ngày hưởng lương cơ bản, không trừ phép năm;
 * nhân viên thử việc / thực tập nghỉ 3 ngày không lương.
 */
public enum PersonalLeaveKind {
    /** Người lao động kết hôn. */
    MARRIAGE,
    /** Người thân của người lao động mất (bố, mẹ, vợ, chồng, con…). */
    BEREAVEMENT;

    public String label() {
        return switch (this) {
            case MARRIAGE -> "NLĐ kết hôn";
            case BEREAVEMENT -> "Người thân NLĐ mất";
        };
    }
}
