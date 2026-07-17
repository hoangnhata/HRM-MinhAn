-- Tên hiển thị từ ERP khi đăng nhập (tài khoản chưa có hồ sơ nhân viên HRM)
ALTER TABLE users
    ADD COLUMN display_name VARCHAR(200) NULL AFTER email;
