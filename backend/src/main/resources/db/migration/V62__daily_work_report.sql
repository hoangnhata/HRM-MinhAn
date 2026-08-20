CREATE TABLE daily_work_reports (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    department_id BIGINT NOT NULL,
    report_date DATE NOT NULL,
    report_type VARCHAR(16) NOT NULL,
    status VARCHAR(16) NOT NULL,
    day_notes TEXT NULL,
    submitted_by_user_id BIGINT NOT NULL,
    submitted_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,
    CONSTRAINT fk_dwr_department FOREIGN KEY (department_id) REFERENCES departments (id),
    CONSTRAINT fk_dwr_submitted_by FOREIGN KEY (submitted_by_user_id) REFERENCES users (id),
    CONSTRAINT uq_dwr_dept_date_type UNIQUE (department_id, report_date, report_type)
);

CREATE TABLE daily_work_report_lines (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_id BIGINT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    workforce_category VARCHAR(255) NULL,
    staff_or_quantity VARCHAR(500) NULL,
    work_content TEXT NULL,
    target_object VARCHAR(500) NULL,
    result_text TEXT NULL,
    line_notes TEXT NULL,
    CONSTRAINT fk_dwrl_report FOREIGN KEY (report_id) REFERENCES daily_work_reports (id) ON DELETE CASCADE
);

CREATE INDEX idx_dwr_report_date ON daily_work_reports (report_date);
CREATE INDEX idx_dwr_report_type ON daily_work_reports (report_type);
CREATE INDEX idx_dwr_status ON daily_work_reports (status);
