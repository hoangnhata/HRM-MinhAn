-- Chữ ký người lập phiếu hội thảo / công tác và công văn đính kèm.

ALTER TABLE seminar_proposal_requests
    ADD COLUMN requester_signature_path VARCHAR(500) NULL AFTER requested_by_user_id;

CREATE TABLE seminar_proposal_attachments (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    proposal_id BIGINT NOT NULL,
    stored_path VARCHAR(500) NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    content_type VARCHAR(120) NOT NULL,
    file_size BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_spa_proposal FOREIGN KEY (proposal_id) REFERENCES seminar_proposal_requests (id) ON DELETE CASCADE
);

CREATE INDEX idx_spa_proposal ON seminar_proposal_attachments (proposal_id);
