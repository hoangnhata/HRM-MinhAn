-- Chữ ký số cá nhân (ảnh PNG/JPG) gắn tài khoản đăng nhập
ALTER TABLE users
    ADD COLUMN signature_path VARCHAR(500) NULL AFTER erp_access_token;
