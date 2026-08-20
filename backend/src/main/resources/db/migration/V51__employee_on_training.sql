ALTER TABLE employees
    ADD COLUMN on_training TINYINT(1) NOT NULL DEFAULT 0 AFTER continuous_shift;
