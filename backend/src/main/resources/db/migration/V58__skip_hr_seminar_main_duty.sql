ALTER TABLE seminar_proposal_requests
    ADD COLUMN with_support TINYINT(1) NULL AFTER with_pay;

-- Chuyển phiếu đang chờ HCNS sang chờ Giám đốc
UPDATE seminar_proposal_requests SET status = 'PENDING_DIRECTOR' WHERE status = 'PENDING_HR';
UPDATE main_duty_authorization_requests SET status = 'PENDING_DIRECTOR' WHERE status = 'PENDING_HR';
