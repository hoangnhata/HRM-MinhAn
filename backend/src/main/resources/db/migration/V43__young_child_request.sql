-- Đơn đề xuất chế độ nuôi con nhỏ (trưởng khoa → HCNS duyệt)

CREATE TABLE young_child_requests (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    period_year INT NOT NULL,
    period_month INT NOT NULL,
    enabled BOOLEAN NOT NULL,
    reason VARCHAR(1000) NULL,
    status VARCHAR(32) NOT NULL,
    requested_by_user_id BIGINT NOT NULL,
    hr_reviewer_id BIGINT NULL,
    hr_reviewed_at TIMESTAMP NULL,
    hr_comment VARCHAR(1000) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_ycr_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_ycr_requested_by FOREIGN KEY (requested_by_user_id) REFERENCES users (id),
    CONSTRAINT fk_ycr_hr FOREIGN KEY (hr_reviewer_id) REFERENCES users (id)
);

CREATE INDEX idx_ycr_status ON young_child_requests (status);
CREATE INDEX idx_ycr_employee_period ON young_child_requests (employee_id, period_year, period_month);
