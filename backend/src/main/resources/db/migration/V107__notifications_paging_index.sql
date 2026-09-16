-- Phân trang thông báo: chưa đọc trước, mới nhất trước, theo từng tài khoản.
-- Chỉ mục cũ (user_id, is_read) không phủ cột sắp xếp nên MySQL phải filesort.
CREATE INDEX idx_notifications_user_read_created ON notifications (user_id, is_read, created_at DESC);

-- Job dọn dẹp xoá thông báo đã đọc theo ngày tạo.
CREATE INDEX idx_notifications_read_created ON notifications (is_read, created_at);
