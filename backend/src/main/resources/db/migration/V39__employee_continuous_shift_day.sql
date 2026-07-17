-- Ca thông tầm theo từng ngày (một tháng có thể lẫn ngày thông tầm và ngày ca thường)

CREATE TABLE employee_continuous_shift_day (
    employee_id BIGINT NOT NULL,
    work_date DATE NOT NULL,
    PRIMARY KEY (employee_id, work_date),
    CONSTRAINT fk_continuous_shift_day_employee
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
);

-- Chuyển dữ liệu tháng cũ → đủ ngày trong tháng tương ứng
INSERT INTO employee_continuous_shift_day (employee_id, work_date)
SELECT m.employee_id, DATE(CONCAT(m.period_year, '-', LPAD(m.period_month, 2, '0'), '-', LPAD(d.n, 2, '0')))
FROM employee_continuous_shift_month m
INNER JOIN (
    SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
    UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
    UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
    UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
    UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL SELECT 24 UNION ALL SELECT 25
    UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28 UNION ALL SELECT 29 UNION ALL SELECT 30
    UNION ALL SELECT 31
) d ON d.n <= DAY(LAST_DAY(DATE(CONCAT(m.period_year, '-', LPAD(m.period_month, 2, '0'), '-01'))))
ON DUPLICATE KEY UPDATE work_date = VALUES(work_date);
