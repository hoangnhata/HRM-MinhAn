-- Giữ nguyên role Giám đốc; quyền duyệt đơn vẫn được điều khiển độc lập
-- bằng director_approval_enabled.
UPDATE users
SET role = 'DIRECTOR'
WHERE role = 'EMPLOYEE'
  AND director_approval_enabled = 1;
