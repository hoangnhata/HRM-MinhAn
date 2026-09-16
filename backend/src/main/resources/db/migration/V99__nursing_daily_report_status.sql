-- Trạng thái gửi / thu hồi báo cáo ĐD hằng ngày
ALTER TABLE nursing_daily_reports
    ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'SUBMITTED' AFTER medication_errors,
    ADD COLUMN submitted_at TIMESTAMP NULL AFTER status;

UPDATE nursing_daily_reports
SET submitted_at = COALESCE(created_at, CURRENT_TIMESTAMP)
WHERE submitted_at IS NULL AND status = 'SUBMITTED';

CREATE INDEX idx_ndr_status ON nursing_daily_reports (status);
