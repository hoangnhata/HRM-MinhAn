-- Giờ vào/ra ca thông tầm tách lập với ca sáng / ca chiều

ALTER TABLE attendance_shift_config
    ADD COLUMN continuous_start TIME NULL AFTER afternoon_end,
    ADD COLUMN continuous_end TIME NULL AFTER continuous_start;

UPDATE attendance_shift_config
SET continuous_start = morning_start,
    continuous_end = afternoon_end
WHERE continuous_start IS NULL OR continuous_end IS NULL;

ALTER TABLE attendance_shift_config
    MODIFY continuous_start TIME NOT NULL,
    MODIFY continuous_end TIME NOT NULL;
