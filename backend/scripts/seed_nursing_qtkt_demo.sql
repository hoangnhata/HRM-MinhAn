-- Demo seed: báo cáo ĐD hằng ngày + QTKT (tháng hiện tại)
-- Chạy: mysql -uroot -p minhan_hrm < backend/scripts/seed_nursing_qtkt_demo.sql
-- Hoặc bật DEMO_SEED=true rồi restart backend (NursingQtktDemoSeedRunner).

SET NAMES utf8mb4;
SET @admin := (SELECT id FROM users WHERE username='admin' LIMIT 1);
SET @from := DATE_FORMAT(CURDATE(), '%Y-%m-01');
SET @to := CURDATE();

INSERT INTO nursing_daily_reports (
  department_id, report_date,
  total_staff, working_staff, planned_leave, unplanned_leave, maternity_leave, long_leave,
  duty_afternoon_off, external_mission,
  inpatients, outpatients, paraclinical, surgery, discharged_yesterday,
  actual_beds, planned_beds, inpatient_treatment_days,
  falls, new_pressure_ulcers, id_mixups, medication_errors,
  created_by_user_id, created_at, updated_at
)
SELECT
  d.id,
  dt.d,
  8 + (d.id % 6),
  GREATEST(4, 8 + (d.id % 6) - IF(DAY(dt.d) % 3 = 0, 1, 0) - IF(DAY(dt.d) % 11 = 0, 1, 0)),
  IF(DAY(dt.d) % 3 = 0, 1, 0),
  IF(DAY(dt.d) % 11 = 0, 1, 0),
  IF(DAY(dt.d) % 17 = 0, 1, 0),
  0,
  IF(DAY(dt.d) % 7 = 0, 1, 0),
  IF(DAY(dt.d) % 21 = 0, 1, 0),
  GREATEST(8, 18 + (d.id % 15) - (DAY(dt.d) % 5) - (d.id % 3)),
  20 + ((d.id * 7 + DAY(dt.d)) % 40),
  5 + ((d.id + DAY(dt.d)) % 15),
  IF(d.name LIKE '%NGOẠI%', 2 + (DAY(dt.d) % 4), DAY(dt.d) % 5),
  1 + (DAY(dt.d) % 4),
  GREATEST(12, 18 + (d.id % 15) - (d.id % 3)),
  18 + (d.id % 15),
  GREATEST(8, 18 + (d.id % 15) - (DAY(dt.d) % 5) - (d.id % 3)),
  IF((d.id * 31 + DAY(dt.d)) % 9 = 0, 1, IF((d.id * 31 + DAY(dt.d)) % 23 = 0, 2, 0)),
  IF((d.id * 31 + DAY(dt.d)) % 13 = 0, 1, 0),
  IF((d.id * 31 + DAY(dt.d)) % 19 = 0, 1, 0),
  IF((d.id * 31 + DAY(dt.d)) % 15 = 0, 1, 0),
  @admin,
  NOW(6),
  NOW(6)
FROM departments d
JOIN (
  SELECT DATE_ADD(@from, INTERVAL seq DAY) AS d
  FROM (
    SELECT a.N + b.N * 10 AS seq
    FROM (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
          UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
    CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) b
  ) x
  WHERE DATE_ADD(@from, INTERVAL seq DAY) <= @to
) dt
WHERE d.id IN (3,4,5,6,7,8,9,10,11,12)
  AND NOT EXISTS (
    SELECT 1 FROM nursing_daily_reports r
    WHERE r.department_id = d.id AND r.report_date = dt.d
  );

-- QTKT kỹ thuật / rửa tay: dùng seed runner Java (DEMO_SEED=true).
-- Tư vấn GDSK: chạy thêm backend/scripts/seed_gdsk_demo.sql
--   "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -uroot -p minhan_hrm < backend/scripts/seed_gdsk_demo.sql
