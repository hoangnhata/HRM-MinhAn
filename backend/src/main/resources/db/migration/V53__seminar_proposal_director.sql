ALTER TABLE seminar_proposal_requests
    ADD COLUMN director_reviewer_id BIGINT NULL AFTER hr_signature_path,
    ADD COLUMN director_reviewed_at TIMESTAMP NULL AFTER director_reviewer_id,
    ADD COLUMN director_comment VARCHAR(1000) NULL AFTER director_reviewed_at,
    ADD COLUMN director_signature_path VARCHAR(500) NULL AFTER director_comment;

ALTER TABLE seminar_proposal_requests
    ADD CONSTRAINT fk_spr_director FOREIGN KEY (director_reviewer_id) REFERENCES users (id);
