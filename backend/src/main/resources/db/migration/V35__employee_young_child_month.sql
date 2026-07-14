-- Nhân viên nuôi con nhỏ theo tháng: giảm 1 giờ/ngày (tối thiểu 7 giờ = 1 công)

CREATE TABLE employee_young_child_month (
    employee_id BIGINT NOT NULL,
    period_year INT NOT NULL,
    period_month INT NOT NULL,
    PRIMARY KEY (employee_id, period_year, period_month),
    CONSTRAINT fk_young_child_employee
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
);
