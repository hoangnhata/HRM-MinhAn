-- Thang bảng lương & hồ sơ lương nhân viên/bác sỹ

CREATE TABLE salary_scale_config (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    scale_type VARCHAR(32) NOT NULL UNIQUE,
    base_total_income DECIMAL(14,2) NOT NULL,
    base_insurance_salary DECIMAL(14,2) NOT NULL,
    base_product_salary DECIMAL(14,2) NOT NULL,
    effective_from DATE NOT NULL DEFAULT (CURRENT_DATE),
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE salary_scale_doctor_entry (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    qualification_code VARCHAR(32) NOT NULL,
    qualification_name VARCHAR(200) NOT NULL,
    time_label VARCHAR(64) NOT NULL,
    years_min DECIMAL(6,3) NOT NULL,
    years_max DECIMAL(6,3),
    total_salary DECIMAL(14,2) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    UNIQUE KEY uk_doctor_scale (qualification_code, time_label)
);

CREATE TABLE employee_salary_profile (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL UNIQUE,
    salary_category VARCHAR(16) NOT NULL,
    employee_block VARCHAR(16),
    tier_group INT NOT NULL DEFAULT 3,
    doctor_qualification_code VARCHAR(32),
    qualification_note VARCHAR(200),
    degree_conversion_years DECIMAL(6,3) NOT NULL DEFAULT 0,
    prior_raise_years DECIMAL(6,3) NOT NULL DEFAULT 0,
    professional_attraction_salary DECIMAL(14,2) NOT NULL DEFAULT 0,
    last_notified_grade INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_esp_emp FOREIGN KEY (employee_id) REFERENCES employees (id)
);

-- Khối trực tiếp (hệ số 1.00 = 5.500.000)
INSERT INTO salary_scale_config (scale_type, base_total_income, base_insurance_salary, base_product_salary, effective_from)
VALUES ('EMPLOYEE_DIRECT', 5500000, 4600000, 900000, '2025-04-01');

-- Khối gián tiếp (hệ số 1.00 = 4.800.000)
INSERT INTO salary_scale_config (scale_type, base_total_income, base_insurance_salary, base_product_salary, effective_from)
VALUES ('EMPLOYEE_INDIRECT', 4800000, 4014545.45, 785454.55, '2025-04-01');

-- Thang bảng bác sỹ (áp dụng từ 4.2025)
INSERT INTO salary_scale_doctor_entry
    (qualification_code, qualification_name, time_label, years_min, years_max, total_salary, sort_order)
VALUES
    ('DK', 'Bác sỹ chưa có CCHN', 'Thử việc', 0, 0, 8000000, 10),
    ('DK', 'Bác sỹ chưa có CCHN', '0-12 tháng', 0, 1, 10000000, 11),
    ('CCHN', 'Bác sỹ có CCHN', '0-2 năm', 0, 2, 11000000, 20),
    ('CCHN', 'Bác sỹ có CCHN', '2-4 năm', 2, 4, 13000000, 21),
    ('CCHN', 'Bác sỹ có CCHN', '4-6 năm', 4, 6, 15000000, 22),
    ('CCHN', 'Bác sỹ có CCHN', '6-8 năm', 6, 8, 17000000, 23),
    ('CCHN', 'Bác sỹ có CCHN', '8-10 năm', 8, 10, 19000000, 24),
    ('CCHN', 'Bác sỹ có CCHN', 'Từ 10 năm trở lên', 10, NULL, 21000000, 25),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '0-2 năm', 0, 2, 12000000, 30),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '2-4 năm', 2, 4, 14000000, 31),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '4-6 năm', 4, 6, 16000000, 32),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '6-8 năm', 6, 8, 18000000, 33),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '8-10 năm', 8, 10, 20000000, 34),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', 'Từ 10 năm trở lên', 10, NULL, 22000000, 35),
    ('CK1', 'CK1', '0-2 năm', 0, 2, 20000000, 40),
    ('CK1', 'CK1', '2-4 năm', 2, 4, 22000000, 41),
    ('CK1', 'CK1', '4-6 năm', 4, 6, 24000000, 42),
    ('CK1', 'CK1', '6-8 năm', 6, 8, 26000000, 43),
    ('CK1', 'CK1', '8-10 năm', 8, 10, 28000000, 44),
    ('CK1', 'CK1', 'Từ 10 năm trở lên', 10, NULL, 30000000, 45),
    ('NOI_TRU', 'Nội trú', '0-2 năm', 0, 2, 40000000, 50),
    ('NOI_TRU', 'Nội trú', '2-4 năm', 2, 4, 44000000, 51),
    ('NOI_TRU', 'Nội trú', '4-6 năm', 4, 6, 48000000, 52),
    ('NOI_TRU', 'Nội trú', '6-8 năm', 6, 8, 52000000, 53),
    ('NOI_TRU', 'Nội trú', '8-10 năm', 8, 10, 56000000, 54),
    ('NOI_TRU', 'Nội trú', 'Từ 10 năm trở lên', 10, NULL, 60000000, 55);
