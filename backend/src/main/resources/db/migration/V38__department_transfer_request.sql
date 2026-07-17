CREATE TABLE department_transfer_requests (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    from_department_id BIGINT NOT NULL,
    to_department_id BIGINT NOT NULL,
    to_position_id BIGINT NULL,
    effective_date DATE NOT NULL,
    reason VARCHAR(1000) NOT NULL,
    status VARCHAR(32) NOT NULL,
    requested_by_user_id BIGINT NOT NULL,
    director_reviewer_id BIGINT NULL,
    director_reviewed_at TIMESTAMP NULL,
    director_comment VARCHAR(1000) NULL,
    applied_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_dtr_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_dtr_from_dept FOREIGN KEY (from_department_id) REFERENCES departments (id),
    CONSTRAINT fk_dtr_to_dept FOREIGN KEY (to_department_id) REFERENCES departments (id),
    CONSTRAINT fk_dtr_to_pos FOREIGN KEY (to_position_id) REFERENCES positions (id),
    CONSTRAINT fk_dtr_requested_by FOREIGN KEY (requested_by_user_id) REFERENCES users (id),
    CONSTRAINT fk_dtr_director FOREIGN KEY (director_reviewer_id) REFERENCES users (id)
);

CREATE INDEX idx_dtr_status_effective ON department_transfer_requests (status, effective_date);
CREATE INDEX idx_dtr_employee ON department_transfer_requests (employee_id);
