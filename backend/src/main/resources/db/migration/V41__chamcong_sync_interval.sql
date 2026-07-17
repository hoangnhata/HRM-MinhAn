-- Đồng bộ máy chấm công theo chu kỳ phút (thay vì chỉ 1 lần/ngày theo giờ hẹn)

ALTER TABLE attendance_chamcong_sync_config
    ADD COLUMN auto_sync_interval_minutes INT NOT NULL DEFAULT 1 AFTER auto_sync_minute;

UPDATE attendance_chamcong_sync_config
SET auto_sync_interval_minutes = 1
WHERE auto_sync_interval_minutes IS NULL OR auto_sync_interval_minutes < 1;
