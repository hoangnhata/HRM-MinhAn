-- Địa điểm công tác (đơn BUSINESS_TRIP)
SET @col_exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'attendance_work_request'
    AND COLUMN_NAME = 'location'
);
SET @sql := IF(
  @col_exists = 0,
  'ALTER TABLE attendance_work_request ADD COLUMN location VARCHAR(255) NULL AFTER reason',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
