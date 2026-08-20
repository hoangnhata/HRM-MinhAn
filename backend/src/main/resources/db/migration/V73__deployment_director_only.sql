-- Các đơn điều động cũ còn đang chờ lãnh đạo/HCNS chuyển thẳng sang Giám đốc.
UPDATE attendance_work_request
SET status = 'PENDING_DIRECTOR'
WHERE request_type = 'DEPLOYMENT'
  AND status IN ('PENDING_HEAD', 'PENDING_HR');
