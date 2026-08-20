-- Quy đổi thời gian nâng lương sớm: danh sách {raiseDate, years}
ALTER TABLE employee_salary_profile
    ADD COLUMN early_raise_conversions JSON NULL;
