-- Mẫu đơn đề nghị ký HĐLĐ chính thức: bác sĩ / điều dưỡng / nhân viên

ALTER TABLE probation_conversion_requests
    ADD COLUMN form_type VARCHAR(16) NOT NULL DEFAULT 'STAFF' AFTER reason,
    ADD COLUMN mentor_comment VARCHAR(2000) NULL AFTER form_type,
    ADD COLUMN head_dept_comment VARCHAR(2000) NULL AFTER mentor_comment,
    ADD COLUMN ward_nurse_head_comment VARCHAR(2000) NULL AFTER head_dept_comment,
    ADD COLUMN hospital_nurse_head_comment VARCHAR(2000) NULL AFTER ward_nurse_head_comment,
    ADD COLUMN scores_json TEXT NULL AFTER hospital_nurse_head_comment,
    ADD COLUMN total_score INT NULL AFTER scores_json,
    ADD COLUMN max_score INT NULL AFTER total_score,
    ADD COLUMN grade_label VARCHAR(64) NULL AFTER max_score,
    ADD COLUMN hr_docs_complete VARCHAR(16) NULL AFTER grade_label,
    ADD COLUMN hr_docs_note VARCHAR(500) NULL AFTER hr_docs_complete,
    ADD COLUMN hr_training_joined VARCHAR(16) NULL AFTER hr_docs_note,
    ADD COLUMN hr_rule_compliance VARCHAR(16) NULL AFTER hr_training_joined,
    ADD COLUMN hr_dept_feedback VARCHAR(16) NULL AFTER hr_rule_compliance,
    ADD COLUMN hr_proposal VARCHAR(32) NULL AFTER hr_dept_feedback;
