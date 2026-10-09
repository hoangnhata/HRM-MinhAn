package com.minhan.hrm.dto.evaluation;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * Lưu / khôi phục mẫu đánh giá. {@code baseVersion} = phiên bản người sửa đã tải về
 * (chống ghi đè khi hai người cùng sửa). {@code template} chỉ cần khi lưu nội dung mới.
 */
@Data
public class NursingEvaluationTemplateSaveRequest {

    @NotNull
    private Integer baseVersion;

    private JsonNode template;

    @Size(max = 500)
    private String changeNote;
}
