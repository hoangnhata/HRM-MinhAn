-- Cột bổ sung từ Excel nhân lực BVMA (không lưu công thức kiểm tra trùng / thâm niên nếu không cần)
ALTER TABLE employee_workforce_details
    ADD COLUMN ethnicity VARCHAR(64) NULL COMMENT 'Dân tộc' AFTER dependents_info,
    ADD COLUMN place_of_origin VARCHAR(255) NULL COMMENT 'Nguyên quán' AFTER ethnicity,
    ADD COLUMN marital_status VARCHAR(64) NULL COMMENT 'Tình trạng hôn nhân' AFTER place_of_origin,
    ADD COLUMN blood_type VARCHAR(16) NULL COMMENT 'Nhóm máu' AFTER marital_status,
    ADD COLUMN emergency_contact VARCHAR(255) NULL COMMENT 'Người liên hệ khẩn cấp' AFTER blood_type,
    ADD COLUMN emergency_phone VARCHAR(32) NULL COMMENT 'Điện thoại liên hệ khẩn cấp' AFTER emergency_contact;
