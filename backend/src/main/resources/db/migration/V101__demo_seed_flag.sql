-- Đánh dấu bản ghi seed demo để xóa an toàn khi DEMO_SEED_CLEANUP=true

ALTER TABLE nursing_daily_reports
    ADD COLUMN is_demo TINYINT(1) NOT NULL DEFAULT 0 AFTER medication_errors;

ALTER TABLE qtkt_evaluations
    ADD COLUMN is_demo TINYINT(1) NOT NULL DEFAULT 0 AFTER note;

CREATE INDEX idx_ndr_is_demo ON nursing_daily_reports (is_demo);
CREATE INDEX idx_qtkt_is_demo ON qtkt_evaluations (is_demo);
