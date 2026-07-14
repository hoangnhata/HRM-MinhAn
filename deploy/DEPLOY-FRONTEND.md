# Deploy frontend lên VM 101 — **không cần IIS**

Backend Spring Boot phục vụ luôn file React tại `C:\hrm\www` trên **cùng port 8086**.

## Trên VM 101 (đã giải nén frontend vào C:\hrm\www)

### Bước 1 — Copy JAR backend mới

Copy `hrm-backend-1.0.0.jar` (bản có `FrontendSpaConfig`) lên `C:\hrm\`.

### Bước 2 — Chạy backend

```bat
C:\hrm\start-hrm.bat
```

Đợi log: `Started HrmApplication`

### Bước 3 — Truy cập

| URL | Kỳ vọng |
|-----|---------|
| http://192.168.31.101:8086/ | Trang đăng nhập HRM |
| http://192.168.31.101:8086/actuator/health | `{"status":"UP"}` |

Đăng nhập: `admin` / `Admin@123`

### Firewall (nếu máy khác không vào được)

```powershell
New-NetFirewallRule -DisplayName "HRM Backend 8086" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8086
```

---

## Trên máy dev (build frontend + backend)

```bat
cd deploy
build-frontend.bat
```

Build backend:

```bat
cd backend
mvn -DskipTests package
copy target\hrm-backend-1.0.0.jar ..\deploy\
```

Copy lên VM:

- `deploy\hrm-frontend-dist.zip` → giải nén bằng `install-frontend-on-vm.ps1`
- `deploy\hrm-backend-1.0.0.jar` → `C:\hrm\`
- `deploy\start-hrm.bat` → `C:\hrm\`

---

## Cập nhật frontend

1. `build-frontend.bat`
2. Copy zip → VM → `install-frontend-on-vm.ps1`
3. Restart `start-hrm.bat` (hoặc chỉ F5 trình duyệt nếu chỉ đổi JS/CSS)

---

## Phương án IIS (tùy chọn, port 80)

Chỉ dùng nếu muốn URL không có `:8080`. Cần URL Rewrite + ARR.

Link Rewrite **đúng** (link cũ bị 404):

```
https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi
```

Chạy `setup-iis-frontend.ps1` (đã sửa link).
