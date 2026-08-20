-- Snapshot chữ ký người duyệt trên từng loại đơn
ALTER TABLE probation_conversion_requests
    ADD COLUMN hr_signature_path VARCHAR(500) NULL AFTER hr_comment,
    ADD COLUMN director_signature_path VARCHAR(500) NULL AFTER director_comment;

ALTER TABLE attendance_work_request
    ADD COLUMN head_signature_path VARCHAR(500) NULL AFTER head_comment,
    ADD COLUMN hr_signature_path VARCHAR(500) NULL AFTER hr_comment;

ALTER TABLE department_transfer_requests
    ADD COLUMN director_signature_path VARCHAR(500) NULL AFTER director_comment;

ALTER TABLE young_child_requests
    ADD COLUMN hr_signature_path VARCHAR(500) NULL AFTER hr_comment;
