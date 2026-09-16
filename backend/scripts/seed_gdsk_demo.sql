-- Seed phiếu tư vấn GDSK demo (tháng hiện tại) để xem báo cáo tuân thủ
-- Idempotent theo unique (employee_id, procedure_code, eval_date, check_context_code, patient_code)

SET NAMES utf8mb4;
SET @admin := (SELECT id FROM users WHERE username = 'admin' LIMIT 1);
SET @from := DATE_FORMAT(CURDATE(), '%Y-%m-01');
SET @to := CURDATE();

-- Điểm đạt đủ 10/10 (đủ tiêu chí bắt buộc 12–14)
SET @scores_pass := '{"GDSK_01":1.0,"GDSK_02":0.5,"GDSK_03":0.75,"GDSK_04":0.75,"GDSK_05":0.75,"GDSK_06":0.75,"GDSK_07":0.5,"GDSK_08":0.5,"GDSK_09":0.5,"GDSK_10":0.5,"GDSK_11":0.5,"GDSK_12":1.0,"GDSK_13":1.0,"GDSK_14":1.0}';
-- Không đạt: thiếu tiêu chí bắt buộc 12
SET @scores_fail := '{"GDSK_01":1.0,"GDSK_02":0.5,"GDSK_03":0.75,"GDSK_04":0.75,"GDSK_05":0.75,"GDSK_06":0.75,"GDSK_07":0.5,"GDSK_08":0.5,"GDSK_09":0.5,"GDSK_10":0.5,"GDSK_11":0.5,"GDSK_12":0.0,"GDSK_13":1.0,"GDSK_14":1.0}';

INSERT INTO qtkt_evaluations (
  employee_id, department_id, procedure_code, procedure_name,
  check_context_code, check_context_label, patient_code, eval_date,
  scores_json, total_score, max_score, note, status,
  created_by_id, updated_by_id, submitted_at, created_at, updated_at
)
SELECT
  e.id,
  d.id,
  'GDSK_COUNSELING',
  'Tư vấn, truyền thông giáo dục sức khỏe',
  '',
  NULL,
  CONCAT('BN', LPAD(d.id % 100, 2, '0'), LPAD(DAY(dt.d), 2, '0'), LPAD(e.id % 90 + p.n, 2, '0')),
  dt.d,
  IF((DAY(dt.d) + e.id + p.n) % 5 = 4, @scores_fail, @scores_pass),
  IF((DAY(dt.d) + e.id + p.n) % 5 = 4, 9.00, 10.00),
  10.00,
  CONCAT('Demo GDSK · BN ', CONCAT('BN', LPAD(d.id % 100, 2, '0'), LPAD(DAY(dt.d), 2, '0'), LPAD(e.id % 90 + p.n, 2, '0'))),
  'SUBMITTED',
  @admin,
  @admin,
  NOW(6),
  NOW(6),
  NOW(6)
FROM departments d
JOIN employees e ON e.department_id = d.id AND e.status = 'ACTIVE'
JOIN (
  SELECT DATE_ADD(@from, INTERVAL seq DAY) AS d
  FROM (
    SELECT a.N + b.N * 10 AS seq
    FROM (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
          UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
    CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2) b
  ) x
  WHERE DATE_ADD(@from, INTERVAL seq DAY) <= @to
    AND (seq % 3) = 0
) dt
JOIN (SELECT 1 AS n UNION SELECT 2) p
WHERE (
    UPPER(REPLACE(REPLACE(REPLACE(d.name, 'Đ', 'D'), 'đ', 'd'), '-', ' ')) LIKE '%NOI%NHI%'
    OR UPPER(d.name) LIKE '%LIÊN CHUYÊN%'
    OR UPPER(d.name) LIKE '%LIEN CHUYEN%'
    OR UPPER(d.name) LIKE '%NGOẠI%'
    OR UPPER(d.name) LIKE '%NGOAI%'
    OR UPPER(d.name) LIKE '%SẢN%'
    OR UPPER(d.name) LIKE '%SAN%'
    OR UPPER(d.name) LIKE '%HỒI SỨC%'
    OR UPPER(d.name) LIKE '%HOI SUC%'
    OR UPPER(d.name) LIKE '%CỔ TRUYỀN%'
    OR UPPER(d.name) LIKE '%CO TRUYEN%'
  )
  AND e.id = (
    SELECT MIN(e2.id) FROM employees e2
    WHERE e2.department_id = d.id AND e2.status = 'ACTIVE'
  )
  AND @admin IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM qtkt_evaluations q
    WHERE q.employee_id = e.id
      AND q.procedure_code = 'GDSK_COUNSELING'
      AND q.eval_date = dt.d
      AND q.check_context_code = ''
      AND q.patient_code = CONCAT('BN', LPAD(d.id % 100, 2, '0'), LPAD(DAY(dt.d), 2, '0'), LPAD(e.id % 90 + p.n, 2, '0'))
  );

SELECT COUNT(*) AS gdsk_demo_rows
FROM qtkt_evaluations
WHERE procedure_code = 'GDSK_COUNSELING'
  AND note LIKE 'Demo GDSK%';
