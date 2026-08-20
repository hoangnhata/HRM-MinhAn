-- Đơn đề xuất chỉnh cấu hình ca sáng/chiều (trưởng khoa → HCNS duyệt)

CREATE TABLE shift_config_change_requests (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    season VARCHAR(16) NOT NULL,
    morning_start TIME NOT NULL,
    morning_end TIME NOT NULL,
    afternoon_start TIME NOT NULL,
    afternoon_end TIME NOT NULL,
    morning_units DECIMAL(10,8) NOT NULL,
    afternoon_units DECIMAL(10,8) NOT NULL,
    reason VARCHAR(1000) NULL,
    status VARCHAR(32) NOT NULL,
    requested_by_user_id BIGINT NOT NULL,
    hr_reviewer_id BIGINT NULL,
    hr_reviewed_at TIMESTAMP NULL,
    hr_comment VARCHAR(1000) NULL,
    hr_signature_path VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_sccr_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_sccr_requested_by FOREIGN KEY (requested_by_user_id) REFERENCES users (id),
    CONSTRAINT fk_sccr_hr FOREIGN KEY (hr_reviewer_id) REFERENCES users (id)
);

CREATE INDEX idx_sccr_status ON shift_config_change_requests (status);
CREATE INDEX idx_sccr_employee_season_status ON shift_config_change_requests (employee_id, season, status);
