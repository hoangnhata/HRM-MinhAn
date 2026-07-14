-- Số lần trừ quên chấm khi duyệt đơn cập nhật (tính theo số mốc thiếu lúc nộp đơn)

ALTER TABLE attendance_work_request
    ADD COLUMN forgot_fine_units INT NULL AFTER hr_waive_forgot_fine;
