-- Danh mục ca thông tầm (nhiều khung giờ) + giờ theo từng ngày gán cho NV

CREATE TABLE continuous_shift_type (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_continuous_shift_type_name UNIQUE (name)
);

INSERT INTO continuous_shift_type (name, start_time, end_time, active)
SELECT 'Ca mặc định (mùa hè)', continuous_start, continuous_end, TRUE
FROM attendance_shift_config
WHERE season = 'SUMMER'
LIMIT 1;

INSERT INTO continuous_shift_type (name, start_time, end_time, active)
SELECT 'Ca mặc định (mùa đông)', c.continuous_start, c.continuous_end, TRUE
FROM attendance_shift_config c
WHERE c.season = 'WINTER'
  AND NOT EXISTS (
      SELECT 1 FROM continuous_shift_type t
      WHERE t.start_time = c.continuous_start
        AND t.end_time = c.continuous_end
  )
LIMIT 1;

ALTER TABLE employee_continuous_shift_day
    ADD COLUMN shift_type_id BIGINT NULL AFTER work_date,
    ADD COLUMN continuous_start TIME NULL AFTER shift_type_id,
    ADD COLUMN continuous_end TIME NULL AFTER continuous_start,
    ADD CONSTRAINT fk_continuous_shift_day_type
        FOREIGN KEY (shift_type_id) REFERENCES continuous_shift_type (id) ON DELETE SET NULL;
