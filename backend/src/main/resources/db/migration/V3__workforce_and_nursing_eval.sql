ALTER TABLE employees
    ADD COLUMN employee_code VARCHAR(64) NULL COMMENT 'Mã nhân viên (theo Excel BVMA)' AFTER id;

CREATE UNIQUE INDEX uk_employees_employee_code ON employees (employee_code);

CREATE TABLE employee_workforce_details (
    employee_id BIGINT NOT NULL PRIMARY KEY,
    payroll_display_name VARCHAR(255),
    duplicate_check_flag VARCHAR(32),
    id_card_issue_date DATE,
    specialty TEXT,
    degree VARCHAR(500),
    bank_account VARCHAR(100),
    bank_name VARCHAR(255),
    work_unit_detail VARCHAR(255),
    insurance_participation VARCHAR(255),
    workforce_notes TEXT,
    probation_start_date DATE,
    official_start_date DATE,
    contract_number VARCHAR(128),
    contract_sign_date DATE,
    contract_term TEXT,
    tenure_text VARCHAR(255),
    social_insurance_book VARCHAR(64),
    attendance_code VARCHAR(64),
    practice_cert_number VARCHAR(128),
    practice_cert_date_raw VARCHAR(64),
    professional_diploma TEXT,
    practice_scope TEXT,
    other_training_certificates TEXT,
    cki TEXT,
    dependents_info TEXT,
    CONSTRAINT fk_ewd_employee FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
);

CREATE TABLE nursing_evaluations (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    evaluator_user_id BIGINT NOT NULL,
    period_year INT NOT NULL,
    period_month INT NOT NULL,
    template_code VARCHAR(64) NOT NULL,
    scores_json TEXT NOT NULL,
    total_self DECIMAL(8, 2),
    total_truong_khoa DECIMAL(8, 2),
    total_ddt DECIMAL(8, 2),
    grade_self VARCHAR(64),
    grade_truong_khoa VARCHAR(64),
    grade_ddt VARCHAR(64),
    comments TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ne_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_ne_evaluator FOREIGN KEY (evaluator_user_id) REFERENCES users (id),
    CONSTRAINT uk_ne_period_template UNIQUE (employee_id, period_year, period_month, template_code)
);

CREATE INDEX idx_nursing_eval_employee ON nursing_evaluations (employee_id);
