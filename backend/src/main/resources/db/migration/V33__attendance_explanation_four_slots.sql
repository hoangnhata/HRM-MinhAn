ALTER TABLE attendance_work_request
    ADD COLUMN explained_morning_in TIME NULL AFTER explained_departure_time,
    ADD COLUMN explained_morning_out TIME NULL AFTER explained_morning_in,
    ADD COLUMN explained_afternoon_in TIME NULL AFTER explained_morning_out,
    ADD COLUMN explained_afternoon_out TIME NULL AFTER explained_afternoon_in;
