-- sso_db — bổ sung cột roleId_ts (Vai trò module Tài sản) trên UserAccounts
-- Dùng cho API "Cấp tài khoản đăng nhập HRM" (POST /api/hrm/employees/{UserEnrollNumber}/account)
-- Idempotent — HRM backend cũng tự chạy lệnh này khi khởi động (minhan.hrm.sso.auto-migrate=true)
-- hoặc qua POST /api/v1/sso/schema/ensure.

IF NOT EXISTS (
    SELECT 1 FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = N'dbo' AND t.name = N'UserAccounts' AND c.name = N'roleId_ts'
)
BEGIN
    ALTER TABLE dbo.UserAccounts ADD roleId_ts INT NULL;
END
GO
