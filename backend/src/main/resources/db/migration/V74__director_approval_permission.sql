ALTER TABLE users
    ADD COLUMN director_approval_enabled BIT(1) NOT NULL DEFAULT 0;

UPDATE users
SET director_approval_enabled = 1
WHERE role IN ('ADMIN', 'DIRECTOR');

-- Ban Giám đốc dùng tài khoản nhân viên thường; quyền duyệt được điều khiển
-- độc lập bằng director_approval_enabled.
UPDATE users
SET role = 'EMPLOYEE'
WHERE role = 'DIRECTOR';
