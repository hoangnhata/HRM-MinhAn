-- Mở rộng cửa sổ giờ vào chiều (quẹt 13:00–13:29 thường gặp sau nghỉ trưa)
UPDATE attendance_shift_config
SET afternoon_in_before_min = 90
WHERE afternoon_in_before_min < 90;
