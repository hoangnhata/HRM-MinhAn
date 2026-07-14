-- Thang bảng lương theo trình độ + bậc (import từ Excel)

CREATE TABLE salary_scale_entry (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    scale_type VARCHAR(32) NOT NULL,
    qualification VARCHAR(200) NOT NULL,
    grade_level INT NOT NULL,
    seniority_from DECIMAL(6,3) NOT NULL,
    seniority_to DECIMAL(6,3),
    coefficient DECIMAL(8,4) NOT NULL,
    base_insurance_salary DECIMAL(14,2) NOT NULL,
    product_salary DECIMAL(14,2) NOT NULL,
    total_income DECIMAL(14,2) NOT NULL,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_scale_qual_grade (scale_type, qualification, grade_level)
);

ALTER TABLE employee_salary_profile
    ADD COLUMN qualification VARCHAR(200) NULL AFTER employee_block;

-- Gán trình độ từ nhóm hệ số cũ (nếu có dữ liệu)
UPDATE employee_salary_profile SET qualification = 'Đại học' WHERE tier_group = 1 AND qualification IS NULL;
UPDATE employee_salary_profile SET qualification = 'Cao đẳng, trung cấp' WHERE tier_group = 2 AND qualification IS NULL;
UPDATE employee_salary_profile SET qualification = 'Lao động phổ thông' WHERE tier_group = 3 AND qualification IS NULL;
