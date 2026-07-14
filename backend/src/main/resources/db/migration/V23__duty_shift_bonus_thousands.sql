-- Mức thưởng trực trong biểu mẫu là nghìn đồng (500 = 500.000đ); dữ liệu cũ lưu thiếu hệ số ×1000.
UPDATE duty_shift_entry
SET bonus_amount = bonus_amount * 1000
WHERE bonus_amount > 0 AND bonus_amount < 1000;
