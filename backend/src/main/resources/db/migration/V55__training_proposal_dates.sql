ALTER TABLE training_proposal_requests
    ADD COLUMN start_date DATE NULL AFTER planned_period,
    ADD COLUMN end_date DATE NULL AFTER start_date;

CREATE INDEX idx_tpr_end_date ON training_proposal_requests (status, end_date);
