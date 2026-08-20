# Trợ lý nhân sự AI

Trợ lý dùng API OpenAI-compatible Chat Completions (hiện cấu hình cho Google Gemini) để chọn các công cụ HRM nội bộ. Lớp AI không truy cập repository hay cơ sở dữ liệu; mọi dữ liệu đều đi qua service hiện có và quyền của tài khoản đăng nhập.

## Cấu hình backend

Thiết lập các biến môi trường trên máy chạy backend:

```text
HR_ASSISTANT_ENABLED=true
GEMINI_API_KEY=...
AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai
HR_ASSISTANT_MODEL=gemini-3.6-flash
```

Các tùy chọn an toàn:

```text
HR_ASSISTANT_MAX_TOOL_CALLS=4
HR_ASSISTANT_MAX_ROUNDS=5
HR_ASSISTANT_RATE_LIMIT_PER_MINUTE=15
HR_ASSISTANT_CONNECT_TIMEOUT_SECONDS=10
HR_ASSISTANT_READ_TIMEOUT_SECONDS=45
```

Có thể dùng nhà cung cấp hỗ trợ OpenAI-compatible Chat Completions. Không tạo biến `VITE_*_API_KEY` và không đưa API key vào frontend. Sau khi đổi biến môi trường, khởi động lại backend.

## API

`POST /j1-api/v1/hr-assistant/chat`

Body chỉ nhận câu hỏi, không nhận `employeeId`:

```json
{ "message": "Tôi còn bao nhiêu ngày phép?" }
```

Endpoint yêu cầu JWT/session hợp lệ. Backend lấy tài khoản và hồ sơ nhân viên từ phiên đăng nhập.

## Nhật ký kiểm tra

Logger `HR_ASSISTANT_AUDIT` ghi: request ID, username, role, tên công cụ, tên các tham số, kết quả thành công/thất bại và thời gian chạy. Nhật ký không ghi nội dung câu hỏi, kết quả công cụ, access token hay API key.
