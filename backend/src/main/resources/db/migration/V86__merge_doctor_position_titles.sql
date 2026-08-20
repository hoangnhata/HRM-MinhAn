-- Gộp chức vụ "Bác sỹ" vào "Bác sĩ" (một bản ghi chuẩn trên hệ thống).
-- Ưu tiên giữ bản ghi đã đặt tên "Bác sĩ"; nếu chưa có thì lấy id nhỏ nhất trong các biến thể.

SET @doctor_position_id := (
    SELECT MIN(id)
    FROM positions
    WHERE LOWER(TRIM(title)) = 'bác sĩ'
);

SET @doctor_position_id := IFNULL(
    @doctor_position_id,
    (
        SELECT MIN(id)
        FROM positions
        WHERE LOWER(TRIM(title)) = 'bác sỹ'
    )
);

UPDATE employees
SET position_id = @doctor_position_id
WHERE @doctor_position_id IS NOT NULL
  AND position_id IN (
      SELECT id
      FROM (
          SELECT id
          FROM positions
          WHERE LOWER(TRIM(title)) IN ('bác sĩ', 'bác sỹ')
      ) doctor_positions
  );

UPDATE department_transfer_requests
SET to_position_id = @doctor_position_id
WHERE @doctor_position_id IS NOT NULL
  AND to_position_id IN (
      SELECT id
      FROM (
          SELECT id
          FROM positions
          WHERE LOWER(TRIM(title)) IN ('bác sĩ', 'bác sỹ')
      ) doctor_positions
  );

DELETE FROM positions
WHERE @doctor_position_id IS NOT NULL
  AND id <> @doctor_position_id
  AND LOWER(TRIM(title)) IN ('bác sĩ', 'bác sỹ');

UPDATE positions
SET title = 'Bác sĩ', level_rank = COALESCE(level_rank, 2)
WHERE id = @doctor_position_id;
