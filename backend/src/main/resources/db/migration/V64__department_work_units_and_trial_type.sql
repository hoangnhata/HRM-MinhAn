-- Bộ phận thuộc phòng ban (1 phòng ban — nhiều bộ phận)
CREATE TABLE department_work_units (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    department_id BIGINT       NOT NULL,
    name          VARCHAR(255) NOT NULL,
    description   VARCHAR(500) NULL,
    created_at    DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6)  NULL,
    CONSTRAINT fk_dwu_department FOREIGN KEY (department_id) REFERENCES departments (id),
    CONSTRAINT uq_dwu_dept_name UNIQUE (department_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_dwu_department ON department_work_units (department_id);

-- Loại thử việc / thực hành từ Excel (THU_VIEC | THUC_HANH | BOTH)
ALTER TABLE employee_workforce_details
    ADD COLUMN trial_type VARCHAR(32) NULL AFTER workforce_notes;
