UPDATE attendance_work_request
SET status = 'PENDING_HR'
WHERE request_type = 'DEPLOYMENT'
  AND status = 'PENDING_DIRECTOR'
  AND hr_reviewed_at IS NULL;
