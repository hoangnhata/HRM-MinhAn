-- Cho phép một đơn chỉnh cả mùa hè + mùa đông
ALTER TABLE shift_config_change_requests
    ADD COLUMN winter_morning_start TIME NULL,
    ADD COLUMN winter_morning_end TIME NULL,
    ADD COLUMN winter_afternoon_start TIME NULL,
    ADD COLUMN winter_afternoon_end TIME NULL;
