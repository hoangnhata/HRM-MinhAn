-- Ảnh đại diện lưu local trên HRM (không phụ thuộc ERP)

ALTER TABLE users
    ADD COLUMN avatar_path VARCHAR(500) NULL AFTER signature_path;
