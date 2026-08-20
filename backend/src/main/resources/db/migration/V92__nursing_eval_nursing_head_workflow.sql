-- Đánh giá ĐD: Trưởng khoa/ĐDT lập → Trưởng phòng ĐD duyệt → HCNS → BGĐ
-- Đổi tên trạng thái bước duyệt đầu (trước đây là PENDING_HEAD / HEAD_REJECTED)

UPDATE nursing_evaluations
SET status = 'PENDING_NURSING_HEAD'
WHERE status = 'PENDING_HEAD';

UPDATE nursing_evaluations
SET status = 'NURSING_HEAD_REJECTED'
WHERE status = 'HEAD_REJECTED';
