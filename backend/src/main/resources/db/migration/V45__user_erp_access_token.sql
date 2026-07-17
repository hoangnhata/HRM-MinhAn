-- Token ERP để gọi GET/PUT /api/auth/profile (không dùng cho JWT HRM)
ALTER TABLE users
    ADD COLUMN erp_access_token TEXT NULL AFTER display_name;
