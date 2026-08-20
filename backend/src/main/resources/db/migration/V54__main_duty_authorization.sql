ALTER TABLE employees
    ADD COLUMN main_duty_authorized TINYINT(1) NOT NULL DEFAULT 0 AFTER on_training;

CREATE TABLE main_duty_authorization_requests (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    form_type VARCHAR(16) NOT NULL,
    accompanying_from DATE NOT NULL,
    accompanying_to DATE NOT NULL,
    effective_from DATE NOT NULL,
    phone VARCHAR(50) NULL,
    address VARCHAR(500) NULL,
    gender VARCHAR(20) NULL,
    degree VARCHAR(255) NULL,
    reason VARCHAR(2000) NULL,
    status VARCHAR(32) NOT NULL,
    requested_by_user_id BIGINT NOT NULL,
    head_reviewer_id BIGINT NULL,
    head_reviewed_at TIMESTAMP NULL,
    head_comment VARCHAR(1000) NULL,
    head_signature_path VARCHAR(500) NULL,
    hr_reviewer_id BIGINT NULL,
    hr_reviewed_at TIMESTAMP NULL,
    hr_comment VARCHAR(1000) NULL,
    hr_signature_path VARCHAR(500) NULL,
    director_reviewer_id BIGINT NULL,
    director_reviewed_at TIMESTAMP NULL,
    director_comment VARCHAR(1000) NULL,
    director_signature_path VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_mda_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_mda_requested_by FOREIGN KEY (requested_by_user_id) REFERENCES users (id),
    CONSTRAINT fk_mda_head FOREIGN KEY (head_reviewer_id) REFERENCES users (id),
    CONSTRAINT fk_mda_hr FOREIGN KEY (hr_reviewer_id) REFERENCES users (id),
    CONSTRAINT fk_mda_director FOREIGN KEY (director_reviewer_id) REFERENCES users (id)
);

CREATE INDEX idx_mda_status ON main_duty_authorization_requests (status);
CREATE INDEX idx_mda_employee ON main_duty_authorization_requests (employee_id);
CREATE INDEX idx_mda_requested_by ON main_duty_authorization_requests (requested_by_user_id);
