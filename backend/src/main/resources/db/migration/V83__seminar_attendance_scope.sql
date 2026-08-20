ALTER TABLE seminar_proposal_requests
    ADD COLUMN attendance_scope VARCHAR(32) NOT NULL DEFAULT 'FULL_DAY';
