CREATE TABLE duty_shift_entry (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    work_date DATE NOT NULL,
    shift_type_code VARCHAR(32) NOT NULL,
    role_tier VARCHAR(32) NOT NULL,
    bonus_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    work_units DECIMAL(5, 2) NOT NULL DEFAULT 0,
    post_duty_pay DECIMAL(15, 2) NOT NULL DEFAULT 0,
    note VARCHAR(500),
    entered_by_user_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,
    CONSTRAINT uk_duty_shift_employee_date UNIQUE (employee_id, work_date),
    CONSTRAINT fk_duty_shift_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_duty_shift_entered_by FOREIGN KEY (entered_by_user_id) REFERENCES users (id)
);

CREATE INDEX idx_duty_shift_employee_date ON duty_shift_entry (employee_id, work_date);
