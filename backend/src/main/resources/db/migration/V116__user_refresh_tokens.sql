-- Phiên đăng nhập dài hạn cho app di động: access token JWT vẫn sống 8 giờ,
-- app dùng refresh token để lấy access token mới thay vì bắt đăng nhập lại.
-- Chỉ lưu SHA-256 của token (không lưu token gốc); đăng xuất / admin reset
-- mật khẩu / khoá tài khoản sẽ thu hồi.
CREATE TABLE user_refresh_tokens (
    id           BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id      BIGINT       NOT NULL,
    token_hash   CHAR(64)     NOT NULL,
    device_label VARCHAR(120) NULL,
    created_at   DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    last_used_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expires_at   DATETIME(6)  NOT NULL,
    revoked_at   DATETIME(6)  NULL,
    CONSTRAINT uk_user_refresh_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_user_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX idx_user_refresh_tokens_user ON user_refresh_tokens (user_id);
