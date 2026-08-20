-- Thêm bước Giám đốc duyệt cuối cho đơn cập nhật công / giải trình
-- Bảng tài khoản là `users` (không phải user_accounts)

ALTER TABLE attendance_work_request
    ADD COLUMN director_reviewer_id BIGINT NULL AFTER hr_waive_forgot_fine,
    ADD COLUMN director_reviewed_at TIMESTAMP NULL AFTER director_reviewer_id,
    ADD COLUMN director_comment VARCHAR(500) NULL AFTER director_reviewed_at,
    ADD COLUMN director_signature_path VARCHAR(500) NULL AFTER director_comment,
    ADD CONSTRAINT fk_attendance_req_director
        FOREIGN KEY (director_reviewer_id) REFERENCES users (id) ON DELETE SET NULL;
