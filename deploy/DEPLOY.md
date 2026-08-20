# Deploy HRM — https://erp.benhvienminhan.com

Hướng dẫn deploy lại HRM khi đã chuyển sang domain ERP.

## Kiến trúc

```text
https://erp.benhvienminhan.com/              → Frontend React (static)
https://erp.benhvienminhan.com/j1-api/*      → Backend Spring Boot (port 8086)
https://erp.benhvienminhan.com/api/auth/*    → ERP Auth (login SSO — backend HRM gọi nội bộ)
```

Frontend gọi API bằng path **tương đối** `/j1-api` (không hardcode domain trong build).

---

## Bước 1 — Build trên máy dev

```bat
cd deploy
build-all.bat
```

Tạo ra:

| File | Mục đích |
|------|----------|
| `deploy/hrm-backend-1.0.0.jar` | Backend API |
| `deploy/hrm-frontend-dist.zip` | Frontend production |
| `deploy/hrm-deploy-bundle.zip` | Gói đủ 3 file + script |
| `deploy/start-hrm.bat` | Khởi động backend trên VM |

Chỉ build một phần:

```bat
deploy\build-backend.bat
deploy\build-frontend.bat
```

---

## Bước 2 — Copy lên server

### VM HRM (backend + MySQL)

Copy vào `C:\hrm\`:

- `hrm-backend-1.0.0.jar`
- `start-hrm.bat`

Sửa mật khẩu / cấu hình trong `start-hrm.bat` nếu cần:

- `MYSQL_PASS` — user MySQL `hrm`
- `JWT_SECRET` — chuỗi bí mật ≥ 32 ký tự
- `SQLSERVER_PASS` — SQL Server chamcong (nếu dùng)
- `GROQ_API_KEY` (hoặc key Gemini) — **bắt buộc** nếu muốn dùng Trợ lý AI trên production
- `HR_ASSISTANT_ENABLED=true` — đã có trong script mẫu; để trống key thì AI vẫn báo chưa cấu hình

Không cần rebuild JAR chỉ để bật AI — chỉ sửa `start-hrm.bat` rồi chạy lại.

### Server phục vụ domain ERP (frontend + reverse proxy)

Copy `hrm-frontend-dist.zip` lên server ERP, giải nén vào thư mục web (ví dụ `C:\inetpub\erp\www` hoặc `C:\hrm\www`).

Trên VM HRM (nếu IIS cùng máy):

```powershell
powershell -ExecutionPolicy Bypass -File C:\hrm\install-frontend-on-vm.ps1
```

---

## Bước 3 — Cấu hình reverse proxy

### IIS (web.config đã có trong zip frontend)

Rule chính — proxy `/j1-api` → backend:

```xml
<match url="^j1-api/(.*)" />
<action type="Rewrite" url="http://127.0.0.1:8086/j1-api/{R:1}" />
```

**Nếu backend ở VM khác** (ví dụ `192.168.31.101`):

```xml
<action type="Rewrite" url="http://192.168.31.101:8086/j1-api/{R:1}" />
```

Cần cài **URL Rewrite** + **ARR**, bật proxy trong IIS.

### Nginx (tham khảo)

```nginx
location /j1-api/ {
    proxy_pass http://192.168.31.101:8086/j1-api/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

location / {
    root /var/www/hrm;
    try_files $uri $uri/ /index.html;
}
```

---

## Bước 4 — Khởi động backend

Trên VM HRM:

```bat
C:\hrm\start-hrm.bat
```

Đợi log: `Started HrmApplication`.

Kiểm tra nội bộ:

```bat
curl http://127.0.0.1:8086/actuator/health
```

Kỳ vọng: `{"status":"UP"}`

---

## Bước 5 — Kiểm tra qua domain

| Kiểm tra | URL | Kỳ vọng |
|----------|-----|---------|
| Frontend | https://erp.benhvienminhan.com/ | Trang đăng nhập HRM |
| Health (nếu proxy thêm) | qua IP nội bộ `:8086/actuator/health` | UP |
| Login API | `POST https://erp.benhvienminhan.com/j1-api/auth/login` | JSON + `accessToken` |
| Me | `GET .../j1-api/v1/account/me` + Bearer | 200 |

Ví dụ login:

```bash
curl -X POST "https://erp.benhvienminhan.com/j1-api/auth/login" ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"0912345678\",\"password\":\"***\"}"
```

F12 → Network: mọi request API phải đi tới `https://erp.benhvienminhan.com/j1-api/...`

---

## Cấu hình đã cập nhật trong code

| File | Thay đổi |
|------|----------|
| `application.yml` | CORS thêm `https://erp.benhvienminhan.com` |
| `application-prod.yml` | Profile prod: CORS, ERP URL, tắt serve SPA |
| `frontend/.env.production` | `VITE_API_URL=/j1-api` |
| `deploy/start-hrm.bat` | Profile prod, domain ERP, port 8086 |
| `deploy/frontend/web.config` | Proxy `/j1-api` → port 8086 |

---

## Firewall

Trên VM HRM — mở port **8086** cho IP gateway ERP (không mở public nếu không cần):

```powershell
New-NetFirewallRule -DisplayName "HRM API 8086 from ERP" `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8086 `
  -RemoteAddress 192.168.8.16
```

(Sửa `RemoteAddress` theo IP server ERP thực tế.)

---

## Deploy lại (cập nhật phiên bản mới)

1. Máy dev: `deploy\build-all.bat`
2. Copy JAR mới → `C:\hrm\` trên VM HRM
3. Copy zip frontend → server ERP → giải nén đè `www`
4. Chạy lại `start-hrm.bat` (script tự dừng instance cũ)
5. Hard refresh trình duyệt (`Ctrl+F5`)

---

## Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách xử lý |
|-------------|-------------|------------|
| `/j1-api` trang trắng, lỗi 404 `/assets/...` | Mở nhầm URL API; proxy `/j1-api` → trang chủ backend | Mở **https://erp.benhvienminhan.com/** (không `/j1-api`). Proxy: `/` → SPA, `/j1-api/` → API |
| CORS error | Origin chưa whitelist | Thêm origin vào `minhan.hrm.cors.allowed-origins` |
| 502 Bad Gateway | Backend chưa chạy | `start-hrm.bat`, kiểm tra port 8086 |
| Login 401 | Sai SĐT/mật khẩu ERP | Dùng tài khoản ERP, không phải MySQL |
| Mixed content | Frontend HTTPS gọi HTTP API | API cũng phải qua HTTPS `/j1-api` |

Swagger (chỉ nội bộ VM): `http://127.0.0.1:8086/swagger-ui.html`

---

## Tài khoản test

Đăng nhập bằng **SĐT + mật khẩu ERP** (xác thực qua `https://erp.benhvienminhan.com/api/auth/login`).

Chi tiết API: xem Swagger hoặc hỏi team dev.
