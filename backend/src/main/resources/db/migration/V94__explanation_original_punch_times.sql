-- Lưu giờ máy chấm gốc khi tạo đơn giải trình (hiển thị trước → sau)
ALTER TABLE attendance_work_request
    ADD COLUMN original_morning_in TIME NULL AFTER explained_afternoon_out,
    ADD COLUMN original_morning_out TIME NULL AFTER original_morning_in,
    ADD COLUMN original_afternoon_in TIME NULL AFTER original_morning_out,
    ADD COLUMN original_afternoon_out TIME NULL AFTER original_afternoon_in;
