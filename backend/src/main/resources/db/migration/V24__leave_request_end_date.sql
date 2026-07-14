-- Đơn nghỉ phép: khoảng ngày (từ work_date đến end_date)
SET @db := DATABASE();

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'attendance_work_request' AND COLUMN_NAME = 'end_date') = 0,
    'ALTER TABLE attendance_work_request ADD COLUMN end_date DATE NULL AFTER work_date',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
