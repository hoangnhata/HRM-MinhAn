ALTER TABLE seminar_proposal_requests
    ADD COLUMN support_amount VARCHAR(255) NULL AFTER with_pay;

ALTER TABLE seminar_proposal_requests
    DROP COLUMN with_support;
