-- Gỡ tính năng báo cáo công việc chi tiết (Báo cáo CV ngày).
DELETE FROM notifications WHERE category = 'DAILY_WORK_REPORT';

DROP TABLE IF EXISTS daily_work_report_lines;
DROP TABLE IF EXISTS daily_work_reports;
