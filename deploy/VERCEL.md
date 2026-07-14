# Deploy frontend lên Vercel

## Lưu ý quan trọng

Backend HRM đang chạy trên **mạng LAN** (`192.168.31.101:8080`, HTTP).

| Vấn đề | Giải thích |
|--------|------------|
| Vercel = **HTTPS** | Trang web từ `*.vercel.app` luôn bảo mật |
| Backend = **HTTP nội bộ** | Trình duyệt **chặn** gọi API HTTP từ trang HTTPS (mixed content) |
| IP LAN | Máy ngoài mạng bệnh viện không truy cập được `192.168.31.101` |

**Kết luận:** Deploy frontend lên Vercel **được**, nhưng muốn dùng thật cần **mở backend ra HTTPS** (Cloudflare Tunnel, Nginx + SSL, hoặc domain nội bộ có chứng chỉ).

**Khuyến nghị cho bệnh viện:** Host frontend trên **cùng VM 101** (IIS/Nginx) + proxy `/api` → `localhost:8080` — không CORS, không mixed content.

---

## Các bước deploy Vercel (khi đã có API HTTPS công khai)

### 1. Đẩy code lên GitHub

Repo phải có thư mục `frontend/`.

### 2. Tạo project trên [vercel.com](https://vercel.com)

- **Import** repository
- **Root Directory:** `frontend`
- **Framework Preset:** Vite
- **Build Command:** `npm run build`
- **Output Directory:** `dist`

### 3. Biến môi trường trên Vercel

| Tên | Giá trị ví dụ |
|-----|----------------|
| `VITE_API_URL` | `https://hrm-api.example.com/api` |

URL phải là **HTTPS** và kết thúc bằng `/api` (hoặc base path API của bạn).

### 4. CORS trên backend (VM 101)

Thêm domain Vercel vào `start-hrm.bat`:

```bat
--minhan.hrm.cors.allowed-origins=http://localhost:5173,https://ten-app-cua-ban.vercel.app ^
```

Khởi động lại backend.

### 5. Deploy

Vercel tự build khi push `main`. Mở URL `https://xxx.vercel.app` và đăng nhập thử.

---

## Deploy bằng CLI (tùy chọn)

```bash
cd frontend
npm install
npx vercel login
npx vercel --prod
```

Khi hỏi env, thêm `VITE_API_URL`.

---

## Giải pháp thay thế: Cloudflare Tunnel (API HTTPS miễn phí)

1. Cài `cloudflared` trên VM 101
2. Tạo tunnel trỏ `hrm-api.tenmien.com` → `http://localhost:8080`
3. Trên Vercel: `VITE_API_URL=https://hrm-api.tenmien.com/api`
4. CORS: thêm `https://xxx.vercel.app`
