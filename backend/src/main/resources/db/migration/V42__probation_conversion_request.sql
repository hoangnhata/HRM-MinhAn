-- Đơn đề nghị chuyển thử việc / thực tập lên chính thức

CREATE TABLE probation_conversion_requests (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    official_date DATE NOT NULL,
    reason VARCHAR(1000) NOT NULL,
    status VARCHAR(32) NOT NULL,
    requested_by_user_id BIGINT NOT NULL,
    hr_reviewer_id BIGINT NULL,
    hr_reviewed_at TIMESTAMP NULL,
    hr_comment VARCHAR(1000) NULL,
    director_reviewer_id BIGINT NULL,
    director_reviewed_at TIMESTAMP NULL,
    director_comment VARCHAR(1000) NULL,
    applied_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_pcr_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_pcr_requested_by FOREIGN KEY (requested_by_user_id) REFERENCES users (id),
    CONSTRAINT fk_pcr_hr FOREIGN KEY (hr_reviewer_id) REFERENCES users (id),
    CONSTRAINT fk_pcr_director FOREIGN KEY (director_reviewer_id) REFERENCES users (id)
);

CREATE INDEX idx_pcr_status_official ON probation_conversion_requests (status, official_date);
CREATE INDEX idx_pcr_employee ON probation_conversion_requests (employee_id);
