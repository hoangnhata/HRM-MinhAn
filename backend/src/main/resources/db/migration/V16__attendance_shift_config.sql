-- Cấu hình lịch ca mùa hè/đông (admin chỉnh sửa) + ca thông tầm theo nhân viên

CREATE TABLE attendance_shift_config (
    season VARCHAR(16) NOT NULL PRIMARY KEY,
    morning_start TIME NOT NULL,
    morning_end TIME NOT NULL,
    afternoon_start TIME NOT NULL,
    afternoon_end TIME NOT NULL,
    morning_units DECIMAL(4, 2) NOT NULL DEFAULT 0.67,
    afternoon_units DECIMAL(4, 2) NOT NULL DEFAULT 0.33,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO attendance_shift_config
    (season, morning_start, morning_end, afternoon_start, afternoon_end, morning_units, afternoon_units)
VALUES
    ('SUMMER', '07:00:00', '12:00:00', '14:00:00', '17:00:00', 0.67, 0.33),
    ('WINTER', '07:30:00', '12:00:00', '14:00:00', '17:30:00', 0.67, 0.33);

ALTER TABLE employees
    ADD COLUMN continuous_shift TINYINT(1) NOT NULL DEFAULT 0 AFTER status;
