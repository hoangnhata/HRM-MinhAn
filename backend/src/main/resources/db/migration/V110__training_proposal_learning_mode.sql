-- Hình thức học của phiếu đề xuất đào tạo: ONLINE | OFFLINE | HYBRID

ALTER TABLE training_proposal_requests
    ADD COLUMN learning_mode VARCHAR(20) NULL AFTER location;

UPDATE training_proposal_requests
SET learning_mode = 'OFFLINE'
WHERE learning_mode IS NULL;
