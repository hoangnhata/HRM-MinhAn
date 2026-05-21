-- Bệnh viện Minh An - HRM — script độc lập (tạo DB rồi chạy toàn bộ file)
-- mysql -u root -p < schema.sql
-- Hoặc: CREATE DATABASE minhan_hrm CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; USE minhan_hrm;
-- RBAC: cột users.role chỉ dùng ADMIN | EMPLOYEE. Nếu DB cũ còn HR: UPDATE users SET role='ADMIN' WHERE role='HR';

CREATE TABLE IF NOT EXISTS departments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(32) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    description VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS positions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(32) NOT NULL UNIQUE,
    title VARCHAR(200) NOT NULL,
    level_rank INT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL,
    enabled BIT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS employees (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    full_name VARCHAR(200) NOT NULL,
    phone VARCHAR(32),
    id_card_number VARCHAR(32),
    date_of_birth DATE,
    address VARCHAR(500),
    gender VARCHAR(16),
    department_id BIGINT NOT NULL,
    position_id BIGINT NOT NULL,
    hire_date DATE NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_emp_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_emp_dept FOREIGN KEY (department_id) REFERENCES departments (id),
    CONSTRAINT fk_emp_pos FOREIGN KEY (position_id) REFERENCES positions (id)
);

CREATE INDEX idx_employees_department ON employees (department_id);
CREATE INDEX idx_employees_status ON employees (status);

CREATE TABLE IF NOT EXISTS contracts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    contract_type VARCHAR(64) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    salary_base DECIMAL(14,2),
    document_path VARCHAR(500),
    note VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_contract_emp FOREIGN KEY (employee_id) REFERENCES employees (id)
);

CREATE INDEX idx_contracts_employee ON contracts (employee_id);

CREATE TABLE IF NOT EXISTS salary_info (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL UNIQUE,
    base_salary DECIMAL(14,2) NOT NULL,
    allowance DECIMAL(14,2) DEFAULT 0,
    last_raise_date DATE,
    next_review_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_salary_emp FOREIGN KEY (employee_id) REFERENCES employees (id)
);

CREATE TABLE IF NOT EXISTS employee_documents (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    stored_path VARCHAR(500) NOT NULL,
    content_type VARCHAR(128),
    doc_type VARCHAR(64) NOT NULL,
    uploaded_by_user_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_doc_emp FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_doc_uploader FOREIGN KEY (uploaded_by_user_id) REFERENCES users (id)
);

CREATE INDEX idx_docs_employee ON employee_documents (employee_id);

CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    category VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BIT(1) NOT NULL DEFAULT 0,
    related_employee_id BIGINT,
    related_announcement_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_notif_emp FOREIGN KEY (related_employee_id) REFERENCES employees (id)
);

CREATE INDEX idx_notifications_announcement ON notifications (related_announcement_id);

CREATE INDEX idx_notifications_user ON notifications (user_id, is_read);

CREATE TABLE IF NOT EXISTS internal_announcements (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    category VARCHAR(64) NOT NULL DEFAULT 'THONG_BAO_CHUNG',
    display_date DATE NULL,
    priority VARCHAR(32) NOT NULL DEFAULT 'NORMAL',
    author_user_id BIGINT NOT NULL,
    published_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    CONSTRAINT fk_ann_author FOREIGN KEY (author_user_id) REFERENCES users (id)
);

CREATE TABLE IF NOT EXISTS announcement_attachments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    announcement_id BIGINT NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    stored_path VARCHAR(500) NOT NULL,
    content_type VARCHAR(128),
    link_label VARCHAR(64) NOT NULL DEFAULT 'tại đây',
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ann_att_ann FOREIGN KEY (announcement_id) REFERENCES internal_announcements (id) ON DELETE CASCADE
);

CREATE INDEX idx_ann_att_announcement ON announcement_attachments (announcement_id);

CREATE TABLE IF NOT EXISTS evaluations (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    evaluator_user_id BIGINT NOT NULL,
    period_year INT NOT NULL,
    period_month INT,
    quarter INT,
    score DECIMAL(5,2) NOT NULL,
    grade VARCHAR(16) NOT NULL,
    comments TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_eval_emp FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT fk_eval_user FOREIGN KEY (evaluator_user_id) REFERENCES users (id)
);

CREATE INDEX idx_evaluations_employee ON evaluations (employee_id);

CREATE TABLE IF NOT EXISTS attendance_records (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    work_date DATE NOT NULL,
    check_in TIME,
    check_out TIME,
    status VARCHAR(32) NOT NULL,
    note VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_att_emp FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT uq_attendance_day UNIQUE (employee_id, work_date)
);

CREATE INDEX idx_attendance_emp_date ON attendance_records (employee_id, work_date);

CREATE TABLE IF NOT EXISTS payroll_records (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    period_year INT NOT NULL,
    period_month INT NOT NULL,
    working_days INT,
    gross_amount DECIMAL(14,2) NOT NULL,
    deduction_amount DECIMAL(14,2) DEFAULT 0,
    net_amount DECIMAL(14,2) NOT NULL,
    note VARCHAR(500),
    finalized BIT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_pay_emp FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT uq_payroll_period UNIQUE (employee_id, period_year, period_month)
);

CREATE INDEX idx_payroll_employee ON payroll_records (employee_id);
