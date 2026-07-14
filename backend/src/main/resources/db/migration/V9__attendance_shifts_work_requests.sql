-- Cột ca sáng/chiều (idempotent nếu V9 đã chạy dở trước đó)
SET @db := DATABASE();

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'attendance_records' AND COLUMN_NAME = 'morning_check_in') = 0,
    'ALTER TABLE attendance_records
        ADD COLUMN morning_check_in TIME NULL,
        ADD COLUMN morning_check_out TIME NULL,
        ADD COLUMN afternoon_check_in TIME NULL,
        ADD COLUMN afternoon_check_out TIME NULL,
        ADD COLUMN morning_work_units DECIMAL(4, 2) NOT NULL DEFAULT 0,
        ADD COLUMN afternoon_work_units DECIMAL(4, 2) NOT NULL DEFAULT 0,
        ADD COLUMN late_minutes INT NOT NULL DEFAULT 0,
        ADD COLUMN late_minutes_exempt TINYINT NOT NULL DEFAULT 0,
        ADD COLUMN forgot_shifts VARCHAR(32) NULL,
        ADD COLUMN punch_times_json TEXT NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS attendance_work_request (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    request_type VARCHAR(24) NOT NULL,
    work_date DATE NOT NULL,
    shift_scope VARCHAR(16) NOT NULL,
    update_kind VARCHAR(32) NULL,
    reason VARCHAR(2000) NOT NULL,
    requested_start TIME NULL,
    requested_end TIME NULL,
    status VARCHAR(32) NOT NULL,
    head_reviewer_id BIGINT NULL,
    head_reviewed_at TIMESTAMP(6) NULL,
    head_comment VARCHAR(500) NULL,
    hr_reviewer_id BIGINT NULL,
    hr_reviewed_at TIMESTAMP(6) NULL,
    hr_comment VARCHAR(500) NULL,
    hr_waive_forgot_fine TINYINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_awr_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_awr_head FOREIGN KEY (head_reviewer_id) REFERENCES users (id),
    CONSTRAINT fk_awr_hr FOREIGN KEY (hr_reviewer_id) REFERENCES users (id),
    INDEX idx_awr_employee_date (employee_id, work_date),
    INDEX idx_awr_status (status)
);
