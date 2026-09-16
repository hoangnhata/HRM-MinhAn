-- Từ 201 phút/tháng: phạt 200.000đ + ghi chú xử lý kỷ luật (không chỉ ghi chú).
UPDATE attendance_late_penalty_tier
SET amount = 200000.00,
    requires_discipline = 1,
    note = COALESCE(NULLIF(TRIM(note), ''), 'Yêu cầu làm bản tự kiểm điểm và xem xét kỷ luật')
WHERE sort_order = 6
  AND min_minutes = 201;
