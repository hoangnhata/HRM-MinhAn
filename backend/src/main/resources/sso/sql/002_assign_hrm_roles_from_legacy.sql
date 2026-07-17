-- Gán role HRM mặc định từ cột legacy UserAccounts.roles
-- admin → ADMIN, còn lại → EMPLOYEE (chỉ account chưa có UserAppRoles HRM)
-- Chạy sau 001_roles_and_user_app_roles.sql

INSERT INTO dbo.UserAppRoles (AccountId, AppCode, RoleId)
SELECT
    ua.AccountId,
    N'HRM',
    r.RoleId
FROM dbo.UserAccounts ua
INNER JOIN dbo.Roles r
    ON r.AppCode = N'HRM'
   AND r.RoleCode = CASE
        WHEN LOWER(LTRIM(RTRIM(ua.roles))) = N'admin' THEN N'ADMIN'
        ELSE N'EMPLOYEE'
    END
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.UserAppRoles uar
    WHERE uar.AccountId = ua.AccountId
      AND uar.AppCode = N'HRM'
);
GO

-- Ví dụ gán tay role chuyên biệt (bỏ comment và sửa AccountId):
-- UPDATE dbo.UserAppRoles SET RoleId = (SELECT RoleId FROM dbo.Roles WHERE AppCode=N'HRM' AND RoleCode=N'HR')
-- WHERE AccountId = 2 AND AppCode = N'HRM';
--
-- UPDATE dbo.UserAppRoles SET RoleId = (SELECT RoleId FROM dbo.Roles WHERE AppCode=N'HRM' AND RoleCode=N'HEAD_DEPARTMENT')
-- WHERE AccountId = 3 AND AppCode = N'HRM';
