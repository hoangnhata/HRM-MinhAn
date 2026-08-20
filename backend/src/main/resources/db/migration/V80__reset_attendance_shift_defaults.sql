-- Chuẩn hóa cấu hình ca và cửa sổ lấy log theo bộ mốc trình diễn 2026.
-- Migration này áp dụng cho cả DB hiện hữu và DB được tạo lại từ đầu.

UPDATE attendance_shift_config
SET morning_start = '06:45:00',
    morning_end = '11:45:00',
    afternoon_start = '14:00:00',
    afternoon_end = '17:00:00',
    continuous_start = '06:45:00',
    continuous_end = '17:00:00',
    morning_in_before_min = 150,
    morning_in_after_min = 120,
    morning_out_before_min = 60,
    morning_out_after_min = 75,
    afternoon_in_before_min = 59,
    afternoon_in_after_min = 60,
    afternoon_out_before_min = 60,
    afternoon_out_after_min = 180
WHERE season = 'SUMMER';

UPDATE attendance_shift_config
SET morning_start = '07:00:00',
    morning_end = '12:00:00',
    afternoon_start = '13:30:00',
    afternoon_end = '16:30:00',
    continuous_start = '07:00:00',
    continuous_end = '16:30:00',
    morning_in_before_min = 180,
    morning_in_after_min = 120,
    morning_out_before_min = 60,
    morning_out_after_min = 60,
    afternoon_in_before_min = 29,
    afternoon_in_after_min = 60,
    afternoon_out_before_min = 60,
    afternoon_out_after_min = 210
WHERE season = 'WINTER';
