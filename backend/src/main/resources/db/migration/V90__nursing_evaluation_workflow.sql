-- Đánh giá NV khối ĐD: quy trình duyệt ký Trưởng khoa/ĐDT → HCNS → Giám đốc

ALTER TABLE nursing_evaluations
    ADD COLUMN status VARCHAR(32) NOT NULL DEFAULT 'APPROVED' AFTER comments,
    ADD COLUMN total_score DECIMAL(8, 2) NULL AFTER status,
    ADD COLUMN overall_grade VARCHAR(64) NULL AFTER total_score,
    ADD COLUMN head_reviewer_id BIGINT NULL AFTER overall_grade,
    ADD COLUMN head_reviewed_at TIMESTAMP NULL AFTER head_reviewer_id,
    ADD COLUMN head_comment VARCHAR(1000) NULL AFTER head_reviewed_at,
    ADD COLUMN head_signature_path VARCHAR(500) NULL AFTER head_comment,
    ADD COLUMN hr_reviewer_id BIGINT NULL AFTER head_signature_path,
    ADD COLUMN hr_reviewed_at TIMESTAMP NULL AFTER hr_reviewer_id,
    ADD COLUMN hr_comment VARCHAR(1000) NULL AFTER hr_reviewed_at,
    ADD COLUMN hr_signature_path VARCHAR(500) NULL AFTER hr_comment,
    ADD COLUMN director_reviewer_id BIGINT NULL AFTER hr_signature_path,
    ADD COLUMN director_reviewed_at TIMESTAMP NULL AFTER director_reviewer_id,
    ADD COLUMN director_comment VARCHAR(1000) NULL AFTER director_reviewed_at,
    ADD COLUMN director_signature_path VARCHAR(500) NULL AFTER director_comment,
    ADD COLUMN updated_at TIMESTAMP NULL AFTER created_at;

ALTER TABLE nursing_evaluations
    ADD CONSTRAINT fk_ne_head FOREIGN KEY (head_reviewer_id) REFERENCES users (id),
    ADD CONSTRAINT fk_ne_hr FOREIGN KEY (hr_reviewer_id) REFERENCES users (id),
    ADD CONSTRAINT fk_ne_director FOREIGN KEY (director_reviewer_id) REFERENCES users (id);

CREATE INDEX idx_ne_status ON nursing_evaluations (status);

-- Bản ghi cũ (chấm đa kênh) coi như đã hoàn tất
UPDATE nursing_evaluations
SET status = 'APPROVED',
    total_score = COALESCE(total_truong_khoa, total_ddt, total_self),
    overall_grade = COALESCE(grade_truong_khoa, grade_ddt, grade_self),
    head_reviewer_id = evaluator_user_id,
    head_reviewed_at = created_at
WHERE status = 'APPROVED';
