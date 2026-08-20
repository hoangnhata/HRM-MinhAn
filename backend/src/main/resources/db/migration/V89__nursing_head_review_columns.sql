-- Bước duyệt Trưởng phòng Điều dưỡng (HEAD_NURSING) cho đơn khối ĐD–KTV–HS–Thư ký y khoa

ALTER TABLE attendance_work_request
    ADD COLUMN nursing_head_reviewer_id BIGINT NULL AFTER head_signature_path,
    ADD COLUMN nursing_head_reviewed_at TIMESTAMP NULL AFTER nursing_head_reviewer_id,
    ADD COLUMN nursing_head_comment VARCHAR(500) NULL AFTER nursing_head_reviewed_at,
    ADD COLUMN nursing_head_signature_path VARCHAR(500) NULL AFTER nursing_head_comment,
    ADD CONSTRAINT fk_awr_nursing_head
        FOREIGN KEY (nursing_head_reviewer_id) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE probation_conversion_requests
    ADD COLUMN nursing_head_reviewer_id BIGINT NULL AFTER requested_by_user_id,
    ADD COLUMN nursing_head_reviewed_at TIMESTAMP NULL AFTER nursing_head_reviewer_id,
    ADD COLUMN nursing_head_comment VARCHAR(1000) NULL AFTER nursing_head_reviewed_at,
    ADD COLUMN nursing_head_signature_path VARCHAR(500) NULL AFTER nursing_head_comment,
    ADD CONSTRAINT fk_pcr_nursing_head
        FOREIGN KEY (nursing_head_reviewer_id) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE main_duty_authorization_requests
    ADD COLUMN nursing_head_reviewer_id BIGINT NULL AFTER head_signature_path,
    ADD COLUMN nursing_head_reviewed_at TIMESTAMP NULL AFTER nursing_head_reviewer_id,
    ADD COLUMN nursing_head_comment VARCHAR(1000) NULL AFTER nursing_head_reviewed_at,
    ADD COLUMN nursing_head_signature_path VARCHAR(500) NULL AFTER nursing_head_comment,
    ADD CONSTRAINT fk_mda_nursing_head
        FOREIGN KEY (nursing_head_reviewer_id) REFERENCES users (id) ON DELETE SET NULL;
