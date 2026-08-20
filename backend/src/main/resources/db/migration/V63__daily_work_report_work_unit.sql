ALTER TABLE daily_work_reports
    ADD COLUMN work_unit VARCHAR(255) NULL AFTER department_id;

UPDATE daily_work_reports r
    INNER JOIN departments d ON r.department_id = d.id
SET r.work_unit = d.name
WHERE r.work_unit IS NULL;

UPDATE daily_work_reports
SET work_unit = 'Bộ phận'
WHERE work_unit IS NULL OR TRIM(work_unit) = '';

ALTER TABLE daily_work_reports
    MODIFY work_unit VARCHAR(255) NOT NULL;

ALTER TABLE daily_work_reports
    DROP FOREIGN KEY fk_dwr_department;

ALTER TABLE daily_work_reports
    DROP INDEX uq_dwr_dept_date_type;

ALTER TABLE daily_work_reports
    DROP COLUMN department_id;

ALTER TABLE daily_work_reports
    ADD CONSTRAINT uq_dwr_unit_date_type UNIQUE (work_unit, report_date, report_type);

CREATE INDEX idx_dwr_work_unit ON daily_work_reports (work_unit);
