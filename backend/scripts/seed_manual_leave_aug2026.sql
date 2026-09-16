-- Tham chiếu: seed chính chạy qua ManualLeaveAug2026SeedRunner khi
-- MANUAL_LEAVE_SEED=true (restart backend). File này chỉ để tra cứu / sửa tay nếu cần.
--
-- Mã NV:
--   Bùi Thị Bình       040192038858  14/08–20/08/2026 (7)
--   Trần Thị Linh      040196003881  03/08–10/08/2026 (8)
--   Nguyễn Thị Phượng  040190039639  10/08–16/08/2026 (7)
--   Luyện Thị Hà       040192022931  01/08–04/08/2026 (4)

SELECT e.id, e.employee_code, e.full_name, d.name AS department
FROM employees e
LEFT JOIN departments d ON d.id = e.department_id
WHERE e.employee_code IN (
  '040192038858',
  '040196003881',
  '040190039639',
  '040192022931'
);

-- Kiểm tra đơn seed sau khi restart:
SELECT r.id, e.employee_code, e.full_name, r.work_date, r.end_date, r.status, r.reason
FROM attendance_work_request r
JOIN employees e ON e.id = r.employee_id
WHERE r.reason LIKE '%[MANUAL_LEAVE_SEED_AUG2026]%'
ORDER BY e.employee_code;

-- Kiểm tra công nghỉ:
SELECT e.employee_code, e.full_name, a.work_date, a.status,
       a.morning_work_units, a.afternoon_work_units, a.note
FROM attendance_records a
JOIN employees e ON e.id = a.employee_id
WHERE e.employee_code IN (
  '040192038858', '040196003881', '040190039639', '040192022931'
)
  AND a.work_date BETWEEN '2026-08-01' AND '2026-08-20'
  AND a.status = 'LEAVE'
ORDER BY e.employee_code, a.work_date;
