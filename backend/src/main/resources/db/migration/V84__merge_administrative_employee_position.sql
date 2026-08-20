-- Gộp "Nhân viên hành chính" vào chức vụ chung "Nhân viên".
-- Chọn bản ghi có id nhỏ nhất làm bản ghi chuẩn để migration vẫn chạy được
-- trong trường hợp dữ liệu cũ chỉ có một trong hai tên.
SET @employee_position_id := (
    SELECT MIN(id)
    FROM positions
    WHERE LOWER(TRIM(title)) IN ('nhân viên', 'nhân viên hành chính')
);

UPDATE employees
SET position_id = @employee_position_id
WHERE @employee_position_id IS NOT NULL
  AND position_id IN (
      SELECT id
      FROM positions
      WHERE LOWER(TRIM(title)) IN ('nhân viên', 'nhân viên hành chính')
  );

UPDATE department_transfer_requests
SET to_position_id = @employee_position_id
WHERE @employee_position_id IS NOT NULL
  AND to_position_id IN (
      SELECT id
      FROM positions
      WHERE LOWER(TRIM(title)) IN ('nhân viên', 'nhân viên hành chính')
  );

DELETE FROM positions
WHERE @employee_position_id IS NOT NULL
  AND id <> @employee_position_id
  AND LOWER(TRIM(title)) IN ('nhân viên', 'nhân viên hành chính');

UPDATE positions
SET title = 'Nhân viên', level_rank = COALESCE(level_rank, 1)
WHERE id = @employee_position_id;
