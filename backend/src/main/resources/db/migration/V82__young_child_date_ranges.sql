-- Chuyển chế độ nuôi con nhỏ từ theo tháng sang khoảng ngày.

CREATE TABLE employee_young_child_period (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_young_child_period_employee
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
    CONSTRAINT chk_young_child_period_dates CHECK (end_date >= start_date)
);

CREATE INDEX idx_ycp_employee_dates
    ON employee_young_child_period (employee_id, start_date, end_date);

INSERT INTO employee_young_child_period (employee_id, start_date, end_date)
SELECT employee_id,
       STR_TO_DATE(CONCAT(period_year, '-', LPAD(period_month, 2, '0'), '-01'), '%Y-%m-%d'),
       LAST_DAY(STR_TO_DATE(CONCAT(period_year, '-', LPAD(period_month, 2, '0'), '-01'), '%Y-%m-%d'))
FROM employee_young_child_month;

ALTER TABLE young_child_requests
    ADD COLUMN start_date DATE NULL AFTER employee_id,
    ADD COLUMN end_date DATE NULL AFTER start_date;

UPDATE young_child_requests
SET start_date = STR_TO_DATE(CONCAT(period_year, '-', LPAD(period_month, 2, '0'), '-01'), '%Y-%m-%d'),
    end_date = LAST_DAY(STR_TO_DATE(CONCAT(period_year, '-', LPAD(period_month, 2, '0'), '-01'), '%Y-%m-%d'))
WHERE start_date IS NULL OR end_date IS NULL;

ALTER TABLE young_child_requests
    MODIFY start_date DATE NOT NULL,
    MODIFY end_date DATE NOT NULL;

CREATE INDEX idx_ycr_employee_dates
    ON young_child_requests (employee_id, start_date, end_date);
