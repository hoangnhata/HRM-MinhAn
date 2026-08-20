# Deploy frontend HRM — domain https://erp.benhvienminhan.com

> Hướng dẫn đầy đủ (backend + frontend + proxy): **[DEPLOY.md](./DEPLOY.md)**

## Tóm tắt

| Thành phần | URL |
|------------|-----|
| Frontend | https://erp.benhvienminhan.com/ |
| API HRM | https://erp.benhvienminhan.com/j1-api |
| Backend nội bộ | `http://<VM-HRM>:8086` |

## Build (máy dev)

```bat
cd deploy
build-frontend.bat
```

Build dùng `VITE_API_URL=/j1-api` (file `frontend/.env.production`).

## Cài trên server

1. Copy `hrm-frontend-dist.zip` lên server
2. Giải nén vào thư mục web ERP (có `index.html`, `assets/`, `web.config`)
3. Đảm bảo IIS/Nginx proxy `/j1-api` → backend port **8086**
4. Backend chạy `C:\hrm\start-hrm.bat` trên VM HRM

## Kiểm tra

- https://erp.benhvienminhan.com/ — trang login
- Đăng nhập → F12 Network → request tới `/j1-api/v1/...`

## Cập nhật frontend

1. `build-frontend.bat`
2. Copy zip → giải nén đè thư mục www
3. `Ctrl+F5` trình duyệt
