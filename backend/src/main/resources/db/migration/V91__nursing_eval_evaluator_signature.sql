-- Chữ ký người lập phiếu đánh giá khối ĐD (Trưởng phòng ĐD) khi gửi duyệt

ALTER TABLE nursing_evaluations
    ADD COLUMN evaluator_signature_path VARCHAR(500) NULL AFTER overall_grade,
    ADD COLUMN evaluator_signed_at TIMESTAMP NULL AFTER evaluator_signature_path;
