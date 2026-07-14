CREATE TABLE IF NOT EXISTS attendance_late_penalty_tier (
    sort_order INT NOT NULL PRIMARY KEY,
    min_minutes INT NOT NULL,
    max_minutes INT NULL,
    amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    requires_discipline TINYINT(1) NOT NULL DEFAULT 0,
    note VARCHAR(255) NULL,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT chk_late_penalty_min_nonneg CHECK (min_minutes >= 0),
    CONSTRAINT chk_late_penalty_max_range CHECK (max_minutes IS NULL OR max_minutes >= min_minutes)
);

INSERT INTO attendance_late_penalty_tier (sort_order, min_minutes, max_minutes, amount, requires_discipline, note) VALUES
(1, 15, 30, 40000.00, 0, NULL),
(2, 31, 50, 50000.00, 0, NULL),
(3, 51, 60, 100000.00, 0, NULL),
(4, 61, 100, 150000.00, 0, NULL),
(5, 101, 200, 200000.00, 0, NULL),
(6, 201, NULL, 0.00, 1, 'Yêu cầu làm bản tự kiểm điểm và xem xét kỷ luật')
ON DUPLICATE KEY UPDATE sort_order = sort_order;
