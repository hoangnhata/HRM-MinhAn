-- sso_db — danh mục role theo app + gán role HRM (không đụng cột roles/RoleId cũ)
-- Chạy trên database: sso_db
-- AccountId lấy đúng kiểu dữ liệu từ dbo.UserAccounts (thường BIGINT, không phải INT)

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = N'dbo' AND t.name = N'Roles'
)
BEGIN
    CREATE TABLE dbo.Roles (
        RoleId       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AppCode      NVARCHAR(32)  NOT NULL,
        RoleCode     NVARCHAR(64)  NOT NULL,
        RoleName     NVARCHAR(128) NOT NULL,
        IsActive     BIT NOT NULL CONSTRAINT DF_Roles_Active DEFAULT (1),
        CONSTRAINT UQ_Roles_App_Code UNIQUE (AppCode, RoleCode)
    );
END
GO

-- Tạo UserAppRoles với AccountId cùng kiểu UserAccounts.AccountId
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

    IF @accountIdType IS NULL
        THROW 50001, N'Không tìm thấy cột dbo.UserAccounts.AccountId', 1;

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
END
GO

MERGE dbo.Roles AS t
USING (VALUES
    (N'HRM', N'ADMIN',           N'Quản trị hệ thống'),
    (N'HRM', N'EMPLOYEE',        N'Nhân viên'),
    (N'HRM', N'HR',              N'Hành chính nhân sự'),
    (N'HRM', N'HEAD_DEPARTMENT', N'Trưởng khoa / phòng'),
    (N'HRM', N'HEAD_NURSING',    N'Điều dưỡng trưởng'),
    (N'HRM', N'DIRECTOR',        N'Giám đốc')
) AS s (AppCode, RoleCode, RoleName)
ON t.AppCode = s.AppCode AND t.RoleCode = s.RoleCode
WHEN NOT MATCHED THEN
    INSERT (AppCode, RoleCode, RoleName, IsActive)
    VALUES (s.AppCode, s.RoleCode, s.RoleName, 1)
WHEN MATCHED AND (t.RoleName <> s.RoleName OR t.IsActive <> 1) THEN
    UPDATE SET RoleName = s.RoleName, IsActive = 1;
GO
