-- Quyền xem báo cáo Trình độ chuyên môn (cấp độc lập bởi Admin).
ALTER TABLE users
    ADD COLUMN professional_qualification_report_enabled BIT(1) NOT NULL DEFAULT 0;

-- ADMIN / HCNS mặc định được xem
UPDATE users
SET professional_qualification_report_enabled = 1
WHERE role IN ('ADMIN', 'HR', 'HR2', 'DIRECTOR');
