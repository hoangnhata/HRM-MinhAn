ALTER TABLE users
    ADD COLUMN hospital_wide_employee_view_enabled BIT(1) NOT NULL DEFAULT 0;
