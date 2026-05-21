-- Gộp vai trò HR cũ vào ADMIN (RBAC chỉ còn ADMIN + EMPLOYEE)
UPDATE users SET role = 'ADMIN' WHERE role = 'HR';
