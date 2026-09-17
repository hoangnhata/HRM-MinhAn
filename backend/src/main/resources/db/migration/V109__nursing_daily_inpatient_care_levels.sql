-- Phân bổ người bệnh nội trú theo 3 cấp chăm sóc (tổng = inpatients)

ALTER TABLE nursing_daily_reports
    ADD COLUMN inpatients_care_level1 INT NOT NULL DEFAULT 0 AFTER inpatients,
    ADD COLUMN inpatients_care_level2 INT NOT NULL DEFAULT 0 AFTER inpatients_care_level1,
    ADD COLUMN inpatients_care_level3 INT NOT NULL DEFAULT 0 AFTER inpatients_care_level2;

-- Phiếu cũ: giữ tổng bằng cách gán hết vào cấp 1 để khi sửa vẫn khớp số đã gửi
UPDATE nursing_daily_reports
SET inpatients_care_level1 = inpatients
WHERE inpatients > 0
  AND inpatients_care_level1 = 0
  AND inpatients_care_level2 = 0
  AND inpatients_care_level3 = 0;
