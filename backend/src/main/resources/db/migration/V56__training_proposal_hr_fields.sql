ALTER TABLE training_proposal_requests
    ADD COLUMN monthly_support VARCHAR(255) NULL AFTER tuition_fee,
    ADD COLUMN post_course_commitment VARCHAR(255) NULL AFTER monthly_support;
