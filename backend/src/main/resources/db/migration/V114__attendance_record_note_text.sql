-- Nhiều đơn điều động trong một ngày (mỗi dòng ~130–180 ký tự) vượt VARCHAR(500)
-- → duyệt đơn bị Data too long / HTTP 500.
ALTER TABLE attendance_records
    MODIFY COLUMN note TEXT NULL;
