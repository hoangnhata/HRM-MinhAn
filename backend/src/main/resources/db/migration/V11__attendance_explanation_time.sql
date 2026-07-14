SET @db := DATABASE();

SET @sql := IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'attendance_work_request' AND COLUMN_NAME = 'explanation_kind') = 0,
    'ALTER TABLE attendance_work_request
        ADD COLUMN explanation_kind VARCHAR(24) NULL AFTER requested_end,
        ADD COLUMN explained_time TIME NULL AFTER explanation_kind',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
