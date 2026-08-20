package com.minhan.hrm.dto.seminar;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class SeminarProposalReviewRequest {

    /** false = từ chối; true = duyệt (cần withPay) */
    private Boolean approved;

    /**
     * Bắt buộc khi Giám đốc duyệt: true = có công, false = không công.
     */
    private Boolean withPay;

    /** Số tiền hỗ trợ hội thảo — tuỳ chọn khi Giám đốc duyệt. */
    @Size(max = 255)
    private String supportAmount;

    private String comment;
}
