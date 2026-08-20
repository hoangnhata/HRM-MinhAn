ALTER TABLE continuous_shift_type
    ADD COLUMN check_in_before_min INT NOT NULL DEFAULT 60,
    ADD COLUMN check_in_after_min INT NOT NULL DEFAULT 120,
    ADD COLUMN check_out_before_min INT NOT NULL DEFAULT 60,
    ADD COLUMN check_out_after_min INT NOT NULL DEFAULT 60;
