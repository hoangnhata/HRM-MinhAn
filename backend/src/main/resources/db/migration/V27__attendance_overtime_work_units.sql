ALTER TABLE attendance_records
    ADD COLUMN overtime_work_units DECIMAL(4, 2) NOT NULL DEFAULT 0;
