-- Đơn công của Trưởng phòng Điều dưỡng bỏ bước "Lãnh đạo duyệt" (chỉ HCNS → Giám đốc).
-- Đơn của Trưởng phòng ĐD đang chờ lãnh đạo lúc nâng cấp: chuyển thẳng sang chờ HCNS.
-- Ghi chú phải trùng hằng số SKIP_HEAD_NURSING_REQUESTER_NOTE trong AttendanceWorkRequestService
-- (giao diện ẩn bước lãnh đạo khi ghi chú khớp).
UPDATE attendance_work_request r
    JOIN employees e ON e.id = r.employee_id
    JOIN users u ON u.id = e.user_id
SET r.status           = 'PENDING_HR',
    r.head_reviewer_id = u.id,
    r.head_reviewed_at = CURRENT_TIMESTAMP,
    r.head_comment     = 'Bỏ qua — đơn của Trưởng phòng Điều dưỡng chuyển thẳng HCNS'
WHERE r.status = 'PENDING_HEAD'
  AND r.request_type <> 'DEPLOYMENT'
  AND u.role = 'HEAD_NURSING';
