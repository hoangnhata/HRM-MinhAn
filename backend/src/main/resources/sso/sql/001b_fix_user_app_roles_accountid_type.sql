-- Chạy khi lần trước lỗi Msg 1778 (AccountId INT ≠ kiểu UserAccounts)
-- Chỉ tạo UserAppRoles nếu chưa có. Roles (6 dòng) giữ nguyên.

USE sso_db;
GO

-- Xem kiểu AccountId thật sự (thường là bigint)
SELECT c.name, TYPE_NAME(c.user_type_id) AS data_type
FROM sys.columns c
JOIN sys.tables t ON t.object_id = c.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = N'dbo' AND t.name = N'UserAccounts' AND c.name = N'AccountId';
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = N'dbo' AND t.name = N'UserAppRoles'
)
BEGIN
    DECLARE @accountIdType SYSNAME;
    DECLARE @sql NVARCHAR(MAX);

    SELECT @accountIdType = TYPE_NAME(c.user_type_id)
    FROM sys.columns c
    INNER JOIN sys.tables t ON t.object_id = c.object_id
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = N'dbo' AND t.name = N'UserAccounts' AND c.name = N'AccountId';

    SET @sql = N'
    CREATE TABLE dbo.UserAppRoles (
        AccountId    ' + QUOTENAME(@accountIdType) + N' NOT NULL,
        AppCode      NVARCHAR(32) NOT NULL,
        RoleId       INT NOT NULL,
        AssignedAt   DATETIME2 NOT NULL CONSTRAINT DF_UAR_Assigned DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_UserAppRoles PRIMARY KEY (AccountId, AppCode),
        CONSTRAINT FK_UAR_Account FOREIGN KEY (AccountId) REFERENCES dbo.UserAccounts(AccountId),
        CONSTRAINT FK_UAR_Role    FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId)
    );';

    EXEC sp_executesql @sql;
    PRINT N'Đã tạo dbo.UserAppRoles với AccountId = ' + @accountIdType;
END
ELSE
    PRINT N'dbo.UserAppRoles đã tồn tại — bỏ qua.';
GO
