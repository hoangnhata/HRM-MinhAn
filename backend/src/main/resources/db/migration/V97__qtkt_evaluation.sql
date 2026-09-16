-- Đánh giá quy trình kỹ thuật (QTKT)

CREATE TABLE qtkt_evaluations (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    department_id BIGINT NOT NULL,
    procedure_code VARCHAR(64) NOT NULL,
    procedure_name VARCHAR(255) NOT NULL,
    eval_date DATE NOT NULL,
    scores_json TEXT NOT NULL,
    total_score DECIMAL(6, 2) NOT NULL DEFAULT 0,
    max_score DECIMAL(6, 2) NOT NULL DEFAULT 10,
    note TEXT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    created_by_id BIGINT NULL,
    updated_by_id BIGINT NULL,
    submitted_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,

    CONSTRAINT uk_qtkt_emp_proc_date UNIQUE (employee_id, procedure_code, eval_date),
    CONSTRAINT ck_qtkt_status CHECK (status IN ('DRAFT', 'SUBMITTED', 'CANCELLED')),
    CONSTRAINT fk_qtkt_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_qtkt_department FOREIGN KEY (department_id) REFERENCES departments (id),
    CONSTRAINT fk_qtkt_created_by FOREIGN KEY (created_by_id) REFERENCES users (id),
    CONSTRAINT fk_qtkt_updated_by FOREIGN KEY (updated_by_id) REFERENCES users (id)
);

CREATE INDEX idx_qtkt_dept_date ON qtkt_evaluations (department_id, eval_date);
CREATE INDEX idx_qtkt_status_date ON qtkt_evaluations (status, eval_date);
CREATE INDEX idx_qtkt_procedure ON qtkt_evaluations (procedure_code, eval_date);
