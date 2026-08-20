-- Hai chức danh dùng chung một role; chức danh hiển thị/nghiệp vụ lấy từ positions.title.
UPDATE users
SET role = 'HEAD_DEPARTMENT'
WHERE role = 'HEAD_NURSING';
