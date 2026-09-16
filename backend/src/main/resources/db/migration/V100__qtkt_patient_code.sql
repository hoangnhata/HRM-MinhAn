-- QTKT: mã bệnh nhân (bắt buộc với phiếu tư vấn GDSK)

SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'qtkt_evaluations'
      AND COLUMN_NAME = 'patient_code'
);
SET @sql_add := IF(
    @col_exists = 0,
    'ALTER TABLE qtkt_evaluations
        ADD COLUMN patient_code VARCHAR(64) NOT NULL DEFAULT '''' AFTER check_context_label',
    'SELECT 1'
);
PREPARE stmt_add FROM @sql_add;
EXECUTE stmt_add;
DEALLOCATE PREPARE stmt_add;

-- Unique: cùng NV / quy trình / ngày / ngữ cảnh / mã BN
SET @old_uk := (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'qtkt_evaluations'
      AND CONSTRAINT_NAME = 'uk_qtkt_emp_proc_date_ctx'
);
SET @sql_drop := IF(
    @old_uk > 0,
    'ALTER TABLE qtkt_evaluations DROP INDEX uk_qtkt_emp_proc_date_ctx',
    'SELECT 1'
);
PREPARE stmt_drop FROM @sql_drop;
EXECUTE stmt_drop;
DEALLOCATE PREPARE stmt_drop;

SET @new_uk := (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'qtkt_evaluations'
      AND CONSTRAINT_NAME = 'uk_qtkt_emp_proc_date_ctx_patient'
);
SET @sql_new := IF(
    @new_uk = 0,
    'ALTER TABLE qtkt_evaluations
        ADD CONSTRAINT uk_qtkt_emp_proc_date_ctx_patient
        UNIQUE (employee_id, procedure_code, eval_date, check_context_code, patient_code)',
    'SELECT 1'
);
PREPARE stmt_new FROM @sql_new;
EXECUTE stmt_new;
DEALLOCATE PREPARE stmt_new;

CREATE INDEX idx_qtkt_patient_code ON qtkt_evaluations (patient_code, eval_date);
