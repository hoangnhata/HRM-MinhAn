-- Quyền duyệt đơn chỉ dành cho role Giám đốc.
-- ADMIN vẫn giữ cờ để nhận thông báo dự phòng và có toàn quyền hệ thống.
UPDATE users
SET director_approval_enabled = 0
WHERE role NOT IN ('ADMIN', 'DIRECTOR');
