-- QTKT: nhiều phiếu / NV / tháng + lựa chọn kiểm tra (vd. thời điểm rửa tay)
-- Idempotent: an toàn khi lần chạy trước đã thêm cột rồi lỗi ở bước DROP INDEX.

SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'qtkt_evaluations'
      AND COLUMN_NAME = 'check_context_code'
);
SET @sql_add_cols := IF(
    @col_exists = 0,
    'ALTER TABLE qtkt_evaluations
        ADD COLUMN check_context_code VARCHAR(64) NOT NULL DEFAULT '''' AFTER procedure_name,
        ADD COLUMN check_context_label VARCHAR(255) NULL AFTER check_context_code',
    'SELECT 1'
);
PREPARE stmt_add_cols FROM @sql_add_cols;
EXECUTE stmt_add_cols;
DEALLOCATE PREPARE stmt_add_cols;

-- FK employee_id đang “ăn” uk_qtkt_emp_proc_date — phải có index riêng trước khi xóa unique cũ.
SET @emp_idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'qtkt_evaluations'
      AND INDEX_NAME = 'idx_qtkt_employee_fk'
);
SET @sql_emp_idx := IF(
    @emp_idx_exists = 0,
    'CREATE INDEX idx_qtkt_employee_fk ON qtkt_evaluations (employee_id)',
    'SELECT 1'
);
PREPARE stmt_emp_idx FROM @sql_emp_idx;
EXECUTE stmt_emp_idx;
DEALLOCATE PREPARE stmt_emp_idx;

SET @old_uk_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'qtkt_evaluations'
      AND INDEX_NAME = 'uk_qtkt_emp_proc_date'
);
SET @sql_drop_old_uk := IF(
    @old_uk_exists > 0,
    'ALTER TABLE qtkt_evaluations DROP INDEX uk_qtkt_emp_proc_date',
    'SELECT 1'
);
PREPARE stmt_drop_old_uk FROM @sql_drop_old_uk;
EXECUTE stmt_drop_old_uk;
DEALLOCATE PREPARE stmt_drop_old_uk;

SET @new_uk_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'qtkt_evaluations'
      AND CONSTRAINT_NAME = 'uk_qtkt_emp_proc_date_ctx'
);
SET @sql_new_uk := IF(
    @new_uk_exists = 0,
    'ALTER TABLE qtkt_evaluations
        ADD CONSTRAINT uk_qtkt_emp_proc_date_ctx
        UNIQUE (employee_id, procedure_code, eval_date, check_context_code)',
    'SELECT 1'
);
PREPARE stmt_new_uk FROM @sql_new_uk;
EXECUTE stmt_new_uk;
DEALLOCATE PREPARE stmt_new_uk;

SET @ctx_idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'qtkt_evaluations'
      AND INDEX_NAME = 'idx_qtkt_check_ctx'
);
SET @sql_ctx_idx := IF(
    @ctx_idx_exists = 0,
    'CREATE INDEX idx_qtkt_check_ctx ON qtkt_evaluations (procedure_code, check_context_code, eval_date)',
    'SELECT 1'
);
PREPARE stmt_ctx_idx FROM @sql_ctx_idx;
EXECUTE stmt_ctx_idx;
DEALLOCATE PREPARE stmt_ctx_idx;
