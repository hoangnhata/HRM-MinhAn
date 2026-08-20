-- Đảm bảo cột tồn tại dạng TEXT (lưu JSON chuỗi) để đọc/ghi ổn định
SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'employee_salary_profile'
      AND COLUMN_NAME = 'early_raise_conversions'
);
SET @sql := IF(
    @col_exists = 0,
    'ALTER TABLE employee_salary_profile ADD COLUMN early_raise_conversions TEXT NULL',
    'ALTER TABLE employee_salary_profile MODIFY COLUMN early_raise_conversions TEXT NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
