-- Công ca: 2/3 sáng + 1/3 chiều (thay 0.67 / 0.33) — đủ số thập phân để tổng = 1

ALTER TABLE attendance_shift_config
    MODIFY COLUMN morning_units DECIMAL(10, 8) NOT NULL,
    MODIFY COLUMN afternoon_units DECIMAL(10, 8) NOT NULL;

ALTER TABLE attendance_records
    MODIFY COLUMN morning_work_units DECIMAL(10, 8) NOT NULL DEFAULT 0,
    MODIFY COLUMN afternoon_work_units DECIMAL(10, 8) NOT NULL DEFAULT 0,
    MODIFY COLUMN overtime_work_units DECIMAL(10, 8) NOT NULL DEFAULT 0;

UPDATE attendance_shift_config
SET morning_units = 0.66666667,
    afternoon_units = 0.33333333;

-- Bản ghi cũ đã ghi 0.67 / 0.33
UPDATE attendance_records
SET morning_work_units = 0.66666667
WHERE morning_work_units IN (0.67, 0.66);

UPDATE attendance_records
SET afternoon_work_units = 0.33333333
WHERE afternoon_work_units IN (0.33, 0.34);

ALTER TABLE duty_shift_entry
    MODIFY COLUMN work_units DECIMAL(10, 8) NOT NULL DEFAULT 0;

UPDATE duty_shift_entry
SET work_units = 0.33333333
WHERE work_units IN (0.33, 0.34);
