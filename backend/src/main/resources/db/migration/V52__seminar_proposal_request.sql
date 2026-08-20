CREATE TABLE seminar_proposal_requests (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    proposing_department VARCHAR(255) NOT NULL,
    seminar_name VARCHAR(500) NOT NULL,
    location VARCHAR(500) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason VARCHAR(2000) NOT NULL,
    employee_commitment_ack TINYINT(1) NOT NULL DEFAULT 1,
    department_commitment_ack TINYINT(1) NOT NULL DEFAULT 1,
    status VARCHAR(32) NOT NULL,
    with_pay TINYINT(1) NULL,
    requested_by_user_id BIGINT NOT NULL,
    hr_reviewer_id BIGINT NULL,
    hr_reviewed_at TIMESTAMP NULL,
    hr_comment VARCHAR(1000) NULL,
    hr_signature_path VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_spr_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_spr_requested_by FOREIGN KEY (requested_by_user_id) REFERENCES users (id),
    CONSTRAINT fk_spr_hr FOREIGN KEY (hr_reviewer_id) REFERENCES users (id)
);

CREATE INDEX idx_spr_status ON seminar_proposal_requests (status);
CREATE INDEX idx_spr_employee ON seminar_proposal_requests (employee_id);
CREATE INDEX idx_spr_requested_by ON seminar_proposal_requests (requested_by_user_id);
CREATE INDEX idx_spr_dates ON seminar_proposal_requests (start_date, end_date);
