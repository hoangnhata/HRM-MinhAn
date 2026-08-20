-- Danh mục ca theo ngày: CONTINUOUS (thông tầm) | SPLIT (sáng/chiều sớm về sớm, đủ ≥8h)

ALTER TABLE continuous_shift_type
    ADD COLUMN kind VARCHAR(20) NOT NULL DEFAULT 'CONTINUOUS';

ALTER TABLE continuous_shift_type
    ADD COLUMN morning_start TIME NULL,
    ADD COLUMN morning_end TIME NULL,
    ADD COLUMN afternoon_start TIME NULL,
    ADD COLUMN afternoon_end TIME NULL,
    ADD COLUMN morning_out_before_min INT NULL,
    ADD COLUMN morning_out_after_min INT NULL,
    ADD COLUMN afternoon_in_before_min INT NULL,
    ADD COLUMN afternoon_in_after_min INT NULL;

UPDATE continuous_shift_type
SET kind = 'CONTINUOUS'
WHERE kind IS NULL OR kind = '';
