CREATE TABLE attendance_chamcong_sync_config (
    id BIGINT NOT NULL PRIMARY KEY,
    auto_sync_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    auto_sync_hour INT NOT NULL DEFAULT 1,
    auto_sync_minute INT NOT NULL DEFAULT 30,
    last_auto_sync_at DATETIME NULL,
    updated_at DATETIME NOT NULL
);

INSERT INTO attendance_chamcong_sync_config (id, auto_sync_enabled, auto_sync_hour, auto_sync_minute, updated_at)
VALUES (1, TRUE, 1, 30, NOW());
