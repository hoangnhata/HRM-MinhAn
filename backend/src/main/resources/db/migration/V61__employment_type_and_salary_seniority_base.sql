-- Loại hợp đồng làm việc: toàn thời gian (TTG) / bán thời gian (BTG)
ALTER TABLE employees
    ADD COLUMN employment_type VARCHAR(16) NOT NULL DEFAULT 'FULL_TIME';

-- Snapshot thâm niên + mốc thang bảng lương từ file nhân lực
ALTER TABLE employee_salary_profile
    ADD COLUMN salary_scale_start_date DATE NULL,
    ADD COLUMN base_seniority_years DECIMAL(10, 6) NULL,
    ADD COLUMN ldg TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN fixed_grade_label VARCHAR(64) NULL;
