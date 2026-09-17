-- Đơn nghỉ chế độ (kết hôn / người thân mất): loại chế độ và cờ hưởng lương chốt lúc nộp.
ALTER TABLE attendance_work_request
    ADD COLUMN personal_leave_kind VARCHAR(24) NULL,
    ADD COLUMN personal_leave_paid BIT NULL;
