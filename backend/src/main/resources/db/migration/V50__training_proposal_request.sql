CREATE TABLE training_proposal_requests (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    proposing_department VARCHAR(255) NOT NULL,
    course_name VARCHAR(500) NOT NULL,
    location VARCHAR(500) NOT NULL,
    planned_period VARCHAR(255) NOT NULL,
    tuition_fee VARCHAR(255) NULL,
    training_goal VARCHAR(2000) NOT NULL,
    reason VARCHAR(2000) NOT NULL,
    employee_commitment_ack TINYINT(1) NOT NULL DEFAULT 1,
    department_commitment_ack TINYINT(1) NOT NULL DEFAULT 1,
    status VARCHAR(32) NOT NULL,
    requested_by_user_id BIGINT NOT NULL,
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
    CONSTRAINT fk_tpr_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_tpr_requested_by FOREIGN KEY (requested_by_user_id) REFERENCES users (id),
    CONSTRAINT fk_tpr_hr FOREIGN KEY (hr_reviewer_id) REFERENCES users (id),
    CONSTRAINT fk_tpr_director FOREIGN KEY (director_reviewer_id) REFERENCES users (id)
);

CREATE INDEX idx_tpr_status ON training_proposal_requests (status);
CREATE INDEX idx_tpr_employee ON training_proposal_requests (employee_id);
CREATE INDEX idx_tpr_requested_by ON training_proposal_requests (requested_by_user_id);
