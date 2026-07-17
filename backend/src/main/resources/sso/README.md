# SSO (`sso_db`) — phân quyền HRM 6 role

Script SQL Server (chạy trên `sso_db`). Không sửa cột legacy `UserAccounts.roles` / `RoleId`.

## Thứ tự chạy (SSMS)

1. [`001_roles_and_user_app_roles.sql`](sql/001_roles_and_user_app_roles.sql) — tạo `Roles`, `UserAppRoles`, seed 6 role `AppCode=HRM`
2. [`001b_fix_user_app_roles_accountid_type.sql`](sql/001b_fix_user_app_roles_accountid_type.sql) — nếu lần chạy 001 lỗi Msg 1778 (AccountId INT ≠ BIGINT), chạy file này
3. [`002_assign_hrm_roles_from_legacy.sql`](sql/002_assign_hrm_roles_from_legacy.sql) — gán mặc định `admin`→`ADMIN`, còn lại→`EMPLOYEE`
4. [`003_useraccounts_roleid_ts.sql`](sql/003_useraccounts_roleid_ts.sql) — bổ sung cột `roleId_ts` (Vai trò Tài sản) cho `UserAccounts`, dùng cho API cấp tài khoản đăng nhập mới (HRM backend tự chạy idempotent lúc khởi động)

## Bật từ HRM API

Trong `application.yml` / env:

```yaml
minhan.hrm.sso.enabled: true   # hoặc SSO_ENABLED=true
minhan.hrm.sso.password: ...   # SSO_DB_PASSWORD
```

Khi bật:

- Khởi động tự `ensureSchema` + `assignDefaults` (nếu `auto-migrate` / `auto-assign-defaults`)
- Public: `GET /api/v1/sso/public/hrm-role?loginPhone=849...`
- Admin: `/api/v1/sso/hrm-roles`, assign, sync-hrm-user, map-role

## Đăng nhập HRM (ERP + SSO role)

1. Xác thực: `POST https://erp.benhvienminhan.com/api/auth/login` (SĐT + mật khẩu) — **không** dùng mật khẩu MySQL.
2. Phân quyền: đọc `UserAppRoles` trên `sso_db` @ `192.168.8.16` theo `LoginPhone`.
3. HRM phát JWT riêng (8 giờ) cho phiên làm việc API nội bộ.


Khi **Thêm / Sửa nhân viên** và đổi **Vai trò**, backend tự cập nhật `UserAppRoles` trên `sso_db` theo **SĐT** (`LoginPhone`).

Cần: hồ sơ NV có số điện thoại trùng (hoặc 9 số cuối) với `UserAccounts.LoginPhone`.

## Cấp tài khoản đăng nhập HRM (mobile qua Gateway)

- `GET /api/hrm/employees?hasAccount=false&search=&page=&limit=&dept=` — nhân viên HRM (theo `employee_workforce_details.attendance_code` = `UserEnrollNumber`) chưa có dòng trong `UserAccounts`.
- `POST /api/hrm/employees/{UserEnrollNumber}/account` — body `{ password, roleId, roleIdTs }` (đều tùy chọn, mặc định `123` / `1` / `3`). Insert `UserAccounts` với `roles=N'guest'`, `RoleId`, `roleId_ts`, `AccountStatus=N'ACTIVE'`; `LoginPhone` tự lấy từ SĐT hồ sơ HRM.
- Quyền: JWT nội bộ HRM role `ADMIN`, `HR` hoặc `DIRECTOR` — thiếu quyền trả `403 { "message": "Bạn không có quyền thực hiện hành động này" }`.
- Cài đặt: `com.minhan.hrm.controller.HrmEmployeeAccountController` + `com.minhan.hrm.sso.SsoEmployeeAccountService`.

