-- Cách khuyến nghị: build jar mới + start-hrm.bat (DEMO_SEED=false, DEMO_SEED_CLEANUP=true) rồi restart.
-- File này chỉ dùng khi muốn xóa thủ công bằng MySQL.

SET NAMES utf8mb4;

DELETE FROM qtkt_evaluations
WHERE is_demo = 1
   OR note LIKE 'Dữ liệu demo test%'
   OR note LIKE 'Demo GDSK%';

DELETE FROM nursing_daily_reports WHERE is_demo = 1;

SELECT 'OK — hoặc dùng DEMO_SEED_CLEANUP=true khi restart backend' AS hint;
