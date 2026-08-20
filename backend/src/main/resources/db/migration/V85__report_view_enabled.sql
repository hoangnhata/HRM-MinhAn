ALTER TABLE users
    ADD COLUMN report_view_enabled BIT(1) NOT NULL DEFAULT 0;

-- ADMIN / HCNS mặc định được xem báo cáo (vẫn có quyền theo vai trò)
UPDATE users
SET report_view_enabled = 1
WHERE role IN ('ADMIN', 'HR', 'HR2', 'DIRECTOR');
