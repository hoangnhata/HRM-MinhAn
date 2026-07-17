package com.minhan.hrm.sso;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.dto.sso.SsoHrmRoleDto;
import com.minhan.hrm.dto.sso.SsoRoleCatalogDto;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Slf4j
@Service
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
public class SsoRoleService {

    private final JdbcTemplate jdbc;
    private final HrmProperties hrmProperties;

    public SsoRoleService(@Qualifier("ssoJdbcTemplate") JdbcTemplate jdbc, HrmProperties hrmProperties) {
        this.jdbc = jdbc;
        this.hrmProperties = hrmProperties;
    }

    private String appCode() {
        String code = hrmProperties.getSso().getAppCode();
        return code == null || code.isBlank() ? SsoUserRoleMapper.APP_CODE_HRM : code.trim();
    }

    /** Tạo Roles / UserAppRoles + seed 6 role HRM (idempotent). */
    public void ensureSchemaAndSeedRoles() {
        jdbc.execute("""
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
                    )
                END
                """);
        jdbc.execute("""
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
                END
                """);

        String app = appCode();
        Map<String, String> seed = Map.of(
                "ADMIN", "Quản trị hệ thống",
                "EMPLOYEE", "Nhân viên",
                "HR", "Hành chính nhân sự",
                "HEAD_DEPARTMENT", "Trưởng khoa / phòng",
                "HEAD_NURSING", "Điều dưỡng trưởng",
                "DIRECTOR", "Giám đốc");
        for (var e : seed.entrySet()) {
            Integer existing = jdbc.query(
                    """
                    SELECT TOP 1 RoleId FROM dbo.Roles
                    WHERE AppCode = ? AND RoleCode = ?
                    """,
                    rs -> rs.next() ? rs.getInt(1) : null,
                    app, e.getKey());
            if (existing == null) {
                jdbc.update(
                        "INSERT INTO dbo.Roles (AppCode, RoleCode, RoleName, IsActive) VALUES (?, ?, ?, 1)",
                        app, e.getKey(), e.getValue());
            } else {
                jdbc.update(
                        "UPDATE dbo.Roles SET RoleName = ?, IsActive = 1 WHERE RoleId = ?",
                        e.getValue(), existing);
            }
        }
        log.info("SSO schema ready — {} roles for AppCode={}", seed.size(), app);
    }

    /**
     * Bổ sung cột roleId_ts (Vai trò module Tài sản) trên UserAccounts nếu chưa có (idempotent).
     * Dùng khi cấp tài khoản đăng nhập HRM mới — không đụng các cột legacy khác.
     */
    public void ensureAccountProvisioningColumns() {
        jdbc.execute("""
                IF NOT EXISTS (
                    SELECT 1 FROM sys.columns c
                    JOIN sys.tables t ON t.object_id = c.object_id
                    JOIN sys.schemas s ON s.schema_id = t.schema_id
                    WHERE s.name = N'dbo' AND t.name = N'UserAccounts' AND c.name = N'roleId_ts'
                )
                BEGIN
                    ALTER TABLE dbo.UserAccounts ADD roleId_ts INT NULL;
                END
                """);
    }

    /**
     * Gán ADMIN/EMPLOYEE từ cột legacy UserAccounts.roles cho account chưa có UserAppRoles HRM.
     * @return số dòng vừa gán
     */
    public int assignDefaultsFromLegacyRoles() {
        String app = appCode();
        return jdbc.update("""
                INSERT INTO dbo.UserAppRoles (AccountId, AppCode, RoleId)
                SELECT
                    ua.AccountId,
                    ?,
                    r.RoleId
                FROM dbo.UserAccounts ua
                INNER JOIN dbo.Roles r
                    ON r.AppCode = ?
                   AND r.RoleCode = CASE
                        WHEN LOWER(LTRIM(RTRIM(ua.roles))) = N'admin' THEN N'ADMIN'
                        ELSE N'EMPLOYEE'
                   END
                WHERE NOT EXISTS (
                    SELECT 1 FROM dbo.UserAppRoles uar
                    WHERE uar.AccountId = ua.AccountId AND uar.AppCode = ?
                )
                """, app, app, app);
    }

    public List<SsoRoleCatalogDto> listHrmRoles() {
        String app = appCode();
        return jdbc.query(
                """
                SELECT RoleId, AppCode, RoleCode, RoleName, IsActive
                FROM dbo.Roles
                WHERE AppCode = ?
                ORDER BY RoleCode
                """,
                (rs, i) -> SsoRoleCatalogDto.builder()
                        .roleId(rs.getInt("RoleId"))
                        .appCode(rs.getString("AppCode"))
                        .roleCode(rs.getString("RoleCode"))
                        .roleName(rs.getString("RoleName"))
                        .active(rs.getBoolean("IsActive"))
                        .build(),
                app);
    }

    /**
     * Danh sách tài khoản ACTIVE + role HRM (lọc mã role ở SQL; q lọc thêm ở tầng service).
     */
    public List<SsoHrmRoleDto> listHrmAccounts(String roleCode) {
        String app = appCode();
        String role = roleCode != null && !roleCode.isBlank() ? roleCode.trim().toUpperCase() : null;

        StringBuilder sql = new StringBuilder("""
                SELECT
                    ua.AccountId,
                    ua.LoginPhone,
                    ua.UserEnrollNumber,
                    r.RoleCode,
                    r.RoleName,
                    uar.AppCode
                FROM dbo.UserAccounts ua
                LEFT JOIN dbo.UserAppRoles uar
                    ON uar.AccountId = ua.AccountId AND uar.AppCode = ?
                LEFT JOIN dbo.Roles r ON r.RoleId = uar.RoleId
                WHERE ua.AccountStatus = N'ACTIVE'
                """);
        java.util.ArrayList<Object> args = new java.util.ArrayList<>();
        args.add(app);

        if (role != null) {
            sql.append(" AND r.RoleCode = ? ");
            args.add(role);
        }
        sql.append(" ORDER BY ua.LoginPhone ");

        return jdbc.query(
                sql.toString(),
                (rs, i) -> SsoHrmRoleDto.builder()
                        .accountId(rs.getLong("AccountId"))
                        .loginPhone(rs.getString("LoginPhone"))
                        .userEnrollNumber(rs.getObject("UserEnrollNumber") != null
                                ? rs.getInt("UserEnrollNumber") : null)
                        .roleCode(rs.getString("RoleCode"))
                        .roleName(rs.getString("RoleName"))
                        .appCode(rs.getString("AppCode") != null ? rs.getString("AppCode") : app)
                        .build(),
                args.toArray());
    }

    public Optional<SsoHrmRoleDto> findHrmRoleByLoginPhone(String loginPhone) {
        if (loginPhone == null || loginPhone.isBlank()) {
            return Optional.empty();
        }
        String phone = normalizePhone(loginPhone);
        String app = appCode();
        List<SsoHrmRoleDto> rows = jdbc.query(
                """
                SELECT TOP 1
                    ua.AccountId,
                    ua.LoginPhone,
                    ua.UserEnrollNumber,
                    r.RoleCode,
                    r.RoleName,
                    uar.AppCode
                FROM dbo.UserAccounts ua
                INNER JOIN dbo.UserAppRoles uar
                    ON uar.AccountId = ua.AccountId AND uar.AppCode = ?
                INNER JOIN dbo.Roles r ON r.RoleId = uar.RoleId
                WHERE ua.AccountStatus = N'ACTIVE'
                  AND (
                       ua.LoginPhone = ?
                    OR ua.LoginPhone = ?
                    OR RIGHT(ua.LoginPhone, 9) = RIGHT(?, 9)
                  )
                """,
                (rs, i) -> SsoHrmRoleDto.builder()
                        .accountId(rs.getLong("AccountId"))
                        .loginPhone(rs.getString("LoginPhone"))
                        .userEnrollNumber(rs.getObject("UserEnrollNumber") != null
                                ? rs.getInt("UserEnrollNumber") : null)
                        .roleCode(rs.getString("RoleCode"))
                        .roleName(rs.getString("RoleName"))
                        .appCode(rs.getString("AppCode"))
                        .build(),
                app, phone, loginPhone.trim(), phone);
        return rows.stream().findFirst();
    }

    public Optional<SsoHrmRoleDto> findHrmRoleByAccountId(long accountId) {
        String app = appCode();
        List<SsoHrmRoleDto> rows = jdbc.query(
                """
                SELECT TOP 1
                    ua.AccountId,
                    ua.LoginPhone,
                    ua.UserEnrollNumber,
                    r.RoleCode,
                    r.RoleName,
                    uar.AppCode
                FROM dbo.UserAccounts ua
                INNER JOIN dbo.UserAppRoles uar
                    ON uar.AccountId = ua.AccountId AND uar.AppCode = ?
                INNER JOIN dbo.Roles r ON r.RoleId = uar.RoleId
                WHERE ua.AccountId = ?
                """,
                (rs, i) -> SsoHrmRoleDto.builder()
                        .accountId(rs.getLong("AccountId"))
                        .loginPhone(rs.getString("LoginPhone"))
                        .userEnrollNumber(rs.getObject("UserEnrollNumber") != null
                                ? rs.getInt("UserEnrollNumber") : null)
                        .roleCode(rs.getString("RoleCode"))
                        .roleName(rs.getString("RoleName"))
                        .appCode(rs.getString("AppCode"))
                        .build(),
                app, accountId);
        return rows.stream().findFirst();
    }

    @Transactional
    public SsoHrmRoleDto assignHrmRole(long accountId, String roleCode) {
        String code = SsoUserRoleMapper.toUserRole(roleCode).name();
        String app = appCode();
        Integer roleId = jdbc.query(
                "SELECT TOP 1 RoleId FROM dbo.Roles WHERE AppCode = ? AND RoleCode = ? AND IsActive = 1",
                rs -> rs.next() ? rs.getInt(1) : null,
                app, code);
        if (roleId == null) {
            throw new ResourceNotFoundException("Không tìm thấy role HRM: " + code);
        }
        Integer exists = jdbc.query(
                "SELECT TOP 1 1 FROM dbo.UserAccounts WHERE AccountId = ?",
                rs -> rs.next() ? 1 : null,
                accountId);
        if (exists == null) {
            throw new ResourceNotFoundException("Không tìm thấy AccountId=" + accountId);
        }
        int updated = jdbc.update(
                "UPDATE dbo.UserAppRoles SET RoleId = ?, AssignedAt = SYSUTCDATETIME() WHERE AccountId = ? AND AppCode = ?",
                roleId, accountId, app);
        if (updated == 0) {
            jdbc.update(
                    "INSERT INTO dbo.UserAppRoles (AccountId, AppCode, RoleId) VALUES (?, ?, ?)",
                    accountId, app, roleId);
        }
        return findHrmRoleByAccountId(accountId)
                .orElseThrow(() -> new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Gán role thất bại"));
    }

    /**
     * Gán role HRM trên SSO theo SĐT (LoginPhone). Dùng khi đổi vai trò trên form nhân viên HRM.
     */
    @Transactional
    public SsoHrmRoleDto assignHrmRoleByLoginPhone(String loginPhone, String roleCode) {
        if (loginPhone == null || loginPhone.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu số điện thoại để gắn role SSO");
        }
        Long accountId = findAccountIdByLoginPhone(loginPhone);
        if (accountId == null) {
            throw new ResourceNotFoundException(
                    "Không tìm thấy tài khoản SSO theo SĐT: " + loginPhone.trim()
                            + " — kiểm tra LoginPhone trên sso_db.UserAccounts");
        }
        return assignHrmRole(accountId, roleCode);
    }

    private Long findAccountIdByLoginPhone(String loginPhone) {
        String phone = normalizePhone(loginPhone);
        List<Long> ids = jdbc.query(
                """
                SELECT TOP 1 ua.AccountId
                FROM dbo.UserAccounts ua
                WHERE ua.AccountStatus = N'ACTIVE'
                  AND (
                       ua.LoginPhone = ?
                    OR ua.LoginPhone = ?
                    OR RIGHT(ua.LoginPhone, 9) = RIGHT(?, 9)
                  )
                """,
                (rs, i) -> rs.getLong(1),
                phone, loginPhone.trim(), phone);
        return ids.isEmpty() ? null : ids.get(0);
    }

    private static String normalizePhone(String raw) {
        String digits = raw.trim().replaceAll("\\D", "");
        if (digits.startsWith("0") && digits.length() >= 10) {
            return "84" + digits.substring(1);
        }
        return digits;
    }

    /**
     * Tên hiển thị trên sso_db (UserAccounts / EmployeePublicProfiles).
     * Dùng cho trang quản trị tài khoản khi chưa khớp hồ sơ HRM.
     */
    public Map<Long, String> loadAccountDisplayNames() {
        Map<Long, String> names = new HashMap<>();
        try {
            mergeDisplayNames(names, loadNamesFromTable("UserAccounts", null));
            mergeDisplayNames(names, loadNamesFromTable("EmployeePublicProfiles", "AccountId"));
            mergeDisplayNames(names, loadProfileNamesByEnroll());
        } catch (Exception ex) {
            log.warn("Không tải đủ tên SSO: {}", ex.getMessage());
        }
        return names;
    }

    private void mergeDisplayNames(Map<Long, String> target, Map<Long, String> source) {
        for (var e : source.entrySet()) {
            target.putIfAbsent(e.getKey(), e.getValue());
        }
    }

    private Map<Long, String> loadNamesFromTable(String table, String accountIdColumnOverride) {
        if (!tableExists(table)) {
            return Map.of();
        }
        List<String> cols = columnNames(table);
        String nameCol = pickNameColumn(cols);
        if (nameCol == null) {
            return Map.of();
        }
        String accountCol = accountIdColumnOverride != null
                ? accountIdColumnOverride
                : pickColumn(cols, "AccountId");
        if (accountCol == null || !cols.contains(accountCol)) {
            return Map.of();
        }
        String sql = """
                SELECT [%s] AS AccountId, LTRIM(RTRIM([%s])) AS DisplayName
                FROM dbo.[%s]
                WHERE [%s] IS NOT NULL AND LTRIM(RTRIM([%s])) <> ''
                """.formatted(accountCol, nameCol, table, nameCol, nameCol);
        Map<Long, String> out = new HashMap<>();
        jdbc.query(sql, rs -> {
            while (rs.next()) {
                String name = rs.getString("DisplayName");
                if (name != null && !name.isBlank()) {
                    out.putIfAbsent(rs.getLong("AccountId"), name.trim());
                }
            }
            return null;
        });
        return out;
    }

    private Map<Long, String> loadProfileNamesByEnroll() {
        if (!tableExists("EmployeePublicProfiles") || !tableExists("UserAccounts")) {
            return Map.of();
        }
        List<String> profileCols = columnNames("EmployeePublicProfiles");
        String nameCol = pickNameColumn(profileCols);
        String enrollCol = pickColumn(profileCols, "UserEnrollNumber", "EnrollNumber", "EmployeeEnrollNumber");
        if (nameCol == null || enrollCol == null) {
            return Map.of();
        }
        String sql = """
                SELECT ua.AccountId, LTRIM(RTRIM(ep.[%s])) AS DisplayName
                FROM dbo.UserAccounts ua
                INNER JOIN dbo.EmployeePublicProfiles ep
                    ON ep.[%s] = ua.UserEnrollNumber
                WHERE ep.[%s] IS NOT NULL AND LTRIM(RTRIM(ep.[%s])) <> ''
                """.formatted(nameCol, enrollCol, nameCol, nameCol);
        Map<Long, String> out = new HashMap<>();
        jdbc.query(sql, rs -> {
            while (rs.next()) {
                String name = rs.getString("DisplayName");
                if (name != null && !name.isBlank()) {
                    out.putIfAbsent(rs.getLong("AccountId"), name.trim());
                }
            }
            return null;
        });
        return out;
    }

    private boolean tableExists(String table) {
        Integer count = jdbc.queryForObject(
                """
                SELECT COUNT(1)
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_SCHEMA = N'dbo' AND TABLE_NAME = ?
                """,
                Integer.class,
                table);
        return count != null && count > 0;
    }

    private List<String> columnNames(String table) {
        return jdbc.query(
                """
                SELECT COLUMN_NAME
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = N'dbo' AND TABLE_NAME = ?
                ORDER BY ORDINAL_POSITION
                """,
                (rs, i) -> rs.getString(1),
                table);
    }

    private static String pickNameColumn(List<String> cols) {
        return pickColumn(cols,
                "FullName", "fullName", "HoTen", "hoTen", "DisplayName", "displayName", "Name", "name");
    }

    private static String pickColumn(List<String> cols, String... candidates) {
        for (String candidate : candidates) {
            for (String col : cols) {
                if (col.equalsIgnoreCase(candidate)) {
                    return col;
                }
            }
        }
        return null;
    }
}
