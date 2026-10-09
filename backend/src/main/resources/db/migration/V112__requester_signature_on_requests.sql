-- Chữ ký người lập phiếu trên mọi loại đơn (phiếu hội thảo đã có ở V111).

ALTER TABLE attendance_work_request
    ADD COLUMN requester_signature_path VARCHAR(500) NULL AFTER status;

ALTER TABLE training_proposal_requests
    ADD COLUMN requester_signature_path VARCHAR(500) NULL AFTER requested_by_user_id;

ALTER TABLE department_transfer_requests
    ADD COLUMN requester_signature_path VARCHAR(500) NULL AFTER requested_by_user_id;

ALTER TABLE probation_conversion_requests
    ADD COLUMN requester_signature_path VARCHAR(500) NULL AFTER requested_by_user_id;

ALTER TABLE main_duty_authorization_requests
    ADD COLUMN requester_signature_path VARCHAR(500) NULL AFTER requested_by_user_id;

ALTER TABLE young_child_requests
    ADD COLUMN requester_signature_path VARCHAR(500) NULL AFTER requested_by_user_id;

ALTER TABLE shift_config_change_requests
    ADD COLUMN requester_signature_path VARCHAR(500) NULL AFTER requested_by_user_id;
