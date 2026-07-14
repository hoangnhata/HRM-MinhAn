-- Hibernate validate expects BIT(1) for boolean fields (V9 used TINYINT on some DBs)
ALTER TABLE attendance_records
    MODIFY COLUMN late_minutes_exempt BIT(1) NOT NULL DEFAULT 0;

ALTER TABLE attendance_work_request
    MODIFY COLUMN hr_waive_forgot_fine BIT(1) NOT NULL DEFAULT 0;
