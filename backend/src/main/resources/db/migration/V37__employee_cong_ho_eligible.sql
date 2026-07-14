-- Nhân viên được phép bổ sung công hộ (không chấm vân tay)

CREATE TABLE employee_cong_ho_eligible (
    employee_id BIGINT NOT NULL,
    PRIMARY KEY (employee_id),
    CONSTRAINT fk_cong_ho_eligible_employee
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
);
