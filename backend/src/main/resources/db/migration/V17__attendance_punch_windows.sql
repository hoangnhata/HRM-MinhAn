-- Cửa sổ lấy giờ chấm công từ log máy (tính từ mốc giờ ca, đơn vị: phút)

ALTER TABLE attendance_shift_config
    ADD COLUMN morning_in_before_min INT NOT NULL DEFAULT 60 AFTER afternoon_units,
    ADD COLUMN morning_in_after_min INT NOT NULL DEFAULT 120 AFTER morning_in_before_min,
    ADD COLUMN morning_out_before_min INT NOT NULL DEFAULT 60 AFTER morning_in_after_min,
    ADD COLUMN morning_out_after_min INT NOT NULL DEFAULT 30 AFTER morning_out_before_min,
    ADD COLUMN afternoon_in_before_min INT NOT NULL DEFAULT 30 AFTER morning_out_after_min,
    ADD COLUMN afternoon_in_after_min INT NOT NULL DEFAULT 60 AFTER afternoon_in_before_min,
    ADD COLUMN afternoon_out_before_min INT NOT NULL DEFAULT 60 AFTER afternoon_in_after_min,
    ADD COLUMN afternoon_out_after_min INT NOT NULL DEFAULT 60 AFTER afternoon_out_before_min;
