ALTER TABLE users
    ADD COLUMN attendance_excel_export_enabled BIT(1) NOT NULL DEFAULT 0;

-- ADMIN / HCNS mặc định được xuất Excel báo cáo công
UPDATE users
SET attendance_excel_export_enabled = 1
WHERE role IN ('ADMIN', 'HR', 'HR2');
