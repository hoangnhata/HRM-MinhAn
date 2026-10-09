-- Mẫu đánh giá NV khối ĐD chỉnh sửa được (ADMIN / Trưởng phòng Điều dưỡng).
-- Mỗi lần lưu tạo một phiên bản; phiên bản mới nhất là mẫu đang dùng.
-- Chưa có phiên bản nào → dùng file JSON gốc trong evaluation-templates/.

CREATE TABLE nursing_evaluation_template_revisions (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    template_code VARCHAR(64) NOT NULL,
    version INT NOT NULL,
    template_json MEDIUMTEXT NOT NULL,
    change_note VARCHAR(500) NULL,
    created_by_id BIGINT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_nurs_eval_tpl_rev UNIQUE (template_code, version),
    CONSTRAINT fk_nurs_eval_tpl_rev_user FOREIGN KEY (created_by_id) REFERENCES users (id)
);

-- Chụp lại mẫu tại thời điểm chấm: phiếu cũ vẫn hiển thị đúng sau khi mẫu bị sửa.
ALTER TABLE nursing_evaluations
    ADD COLUMN template_version INT NULL,
    ADD COLUMN template_snapshot_json MEDIUMTEXT NULL;
