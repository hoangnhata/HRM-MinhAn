-- Báo cáo điều dưỡng hằng ngày (1 khoa / 1 ngày)

CREATE TABLE nursing_daily_reports (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    department_id BIGINT NOT NULL,
    report_date DATE NOT NULL,

    total_staff INT NOT NULL DEFAULT 0,
    working_staff INT NOT NULL DEFAULT 0,
    planned_leave INT NOT NULL DEFAULT 0,
    unplanned_leave INT NOT NULL DEFAULT 0,
    maternity_leave INT NOT NULL DEFAULT 0,
    long_leave INT NOT NULL DEFAULT 0,
    duty_afternoon_off INT NOT NULL DEFAULT 0,
    external_mission INT NOT NULL DEFAULT 0,

    inpatients INT NOT NULL DEFAULT 0,
    outpatients INT NOT NULL DEFAULT 0,
    paraclinical INT NOT NULL DEFAULT 0,
    surgery INT NOT NULL DEFAULT 0,
    discharged_yesterday INT NOT NULL DEFAULT 0,

    actual_beds INT NOT NULL DEFAULT 0,
    planned_beds INT NOT NULL DEFAULT 0,

    inpatient_treatment_days INT NOT NULL DEFAULT 0,

    falls INT NOT NULL DEFAULT 0,
    new_pressure_ulcers INT NOT NULL DEFAULT 0,
    id_mixups INT NOT NULL DEFAULT 0,
    medication_errors INT NOT NULL DEFAULT 0,

    created_by_user_id BIGINT NOT NULL,
    updated_by_user_id BIGINT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,

    CONSTRAINT uk_ndr_dept_date UNIQUE (department_id, report_date),
    CONSTRAINT fk_ndr_department FOREIGN KEY (department_id) REFERENCES departments (id),
    CONSTRAINT fk_ndr_created_by FOREIGN KEY (created_by_user_id) REFERENCES users (id),
    CONSTRAINT fk_ndr_updated_by FOREIGN KEY (updated_by_user_id) REFERENCES users (id)
);

CREATE INDEX idx_ndr_report_date ON nursing_daily_reports (report_date);
CREATE INDEX idx_ndr_department ON nursing_daily_reports (department_id);
