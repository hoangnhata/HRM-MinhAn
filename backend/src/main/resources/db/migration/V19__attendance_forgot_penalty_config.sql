CREATE TABLE IF NOT EXISTS attendance_forgot_penalty_config (
    id BIGINT NOT NULL PRIMARY KEY DEFAULT 1,
    tier1_amount DECIMAL(12, 2) NOT NULL DEFAULT 10000.00,
    tier2_min INT NOT NULL DEFAULT 2,
    tier2_max INT NOT NULL DEFAULT 4,
    tier2_amount DECIMAL(12, 2) NOT NULL DEFAULT 50000.00,
    tier3_amount DECIMAL(12, 2) NOT NULL DEFAULT 100000.00,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT chk_forgot_penalty_singleton CHECK (id = 1),
    CONSTRAINT chk_forgot_penalty_tier2_range CHECK (tier2_min >= 2 AND tier2_max >= tier2_min)
);

INSERT INTO attendance_forgot_penalty_config (id, tier1_amount, tier2_min, tier2_max, tier2_amount, tier3_amount)
VALUES (1, 10000.00, 2, 4, 50000.00, 100000.00)
ON DUPLICATE KEY UPDATE id = id;
