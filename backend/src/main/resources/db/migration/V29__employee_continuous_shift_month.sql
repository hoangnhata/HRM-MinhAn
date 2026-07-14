-- Ca thông tầm theo từng tháng (mỗi nhân viên có thể bật/tắt riêng từng tháng)

CREATE TABLE employee_continuous_shift_month (
    employee_id BIGINT NOT NULL,
    period_year INT NOT NULL,
    period_month INT NOT NULL,
    PRIMARY KEY (employee_id, period_year, period_month),
    CONSTRAINT fk_continuous_shift_employee
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
);

-- Chuyển cờ continuous_shift cũ (toàn nhân viên) sang bảng tháng năm 2026
INSERT INTO employee_continuous_shift_month (employee_id, period_year, period_month)
SELECT e.id, 2026, m.n
FROM employees e
CROSS JOIN (
    SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
    UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
) m
WHERE e.continuous_shift = 1;
