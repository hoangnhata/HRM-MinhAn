ALTER TABLE attendance_work_request
    ADD COLUMN requested_afternoon_start TIME NULL,
    ADD COLUMN requested_afternoon_end TIME NULL;
