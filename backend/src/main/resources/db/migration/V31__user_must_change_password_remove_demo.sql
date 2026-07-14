-- Bắt đổi mật khẩu lần đầu + xóa tài khoản demo nhanvien

ALTER TABLE users
    ADD COLUMN must_change_password BIT(1) NOT NULL DEFAULT 0 AFTER enabled;

-- Xóa nhân viên demo (username nhanvien) nếu còn tồn tại
SET @demo_user_id := (SELECT id FROM users WHERE username = 'nhanvien' LIMIT 1);
SET @demo_emp_id := (SELECT id FROM employees WHERE user_id = @demo_user_id LIMIT 1);

DELETE FROM attendance_work_request WHERE employee_id = @demo_emp_id;
DELETE FROM attendance_records WHERE employee_id = @demo_emp_id;
DELETE FROM duty_shift_entry WHERE employee_id = @demo_emp_id;
DELETE FROM employee_continuous_shift_month WHERE employee_id = @demo_emp_id;
DELETE FROM payroll_records WHERE employee_id = @demo_emp_id;
DELETE FROM nursing_evaluations WHERE employee_id = @demo_emp_id;
DELETE FROM evaluations WHERE employee_id = @demo_emp_id;
DELETE FROM contracts WHERE employee_id = @demo_emp_id;
DELETE FROM employee_salary_profile WHERE employee_id = @demo_emp_id;
DELETE FROM salary_info WHERE employee_id = @demo_emp_id;
DELETE FROM employee_workforce_details WHERE employee_id = @demo_emp_id;
DELETE FROM employee_documents WHERE employee_id = @demo_emp_id;
UPDATE notifications SET related_employee_id = NULL WHERE related_employee_id = @demo_emp_id;
DELETE FROM employees WHERE id = @demo_emp_id;
DELETE FROM notifications WHERE user_id = @demo_user_id;
DELETE FROM users WHERE id = @demo_user_id;
