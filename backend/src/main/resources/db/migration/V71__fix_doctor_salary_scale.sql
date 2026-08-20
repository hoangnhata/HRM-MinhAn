-- Đồng bộ thang bảng lương bác sỹ theo sheet «tbl» file nhân lực BVMA.
-- CCHN / CCHNCT trước đây bị đảo số; bổ sung ĐKCT; CCHN không có bậc 10+.

DELETE FROM salary_scale_doctor_entry;

INSERT INTO salary_scale_doctor_entry
    (qualification_code, qualification_name, time_label, years_min, years_max, total_salary, sort_order)
VALUES
    ('DK', 'Bác sỹ chưa có CCHN', 'Thử việc', 0, 0, 8000000, 10),
    ('DK', 'Bác sỹ chưa có CCHN', '0-12 tháng', 0, 1, 10000000, 11),
    ('DKCT', 'Bác sỹ chưa có CCHN (ĐKCT)', '0-12 tháng', 0, 1, 10000000, 12),
    ('CCHN', 'Bác sỹ có CCHN', '0-2 năm', 0, 2, 12000000, 20),
    ('CCHN', 'Bác sỹ có CCHN', '2-4 năm', 2, 4, 14000000, 21),
    ('CCHN', 'Bác sỹ có CCHN', '4-6 năm', 4, 6, 16000000, 22),
    ('CCHN', 'Bác sỹ có CCHN', '6-8 năm', 6, 8, 18000000, 23),
    ('CCHN', 'Bác sỹ có CCHN', '8-10 năm', 8, 10, 20000000, 24),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '0-2 năm', 0, 2, 11000000, 30),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '2-4 năm', 2, 4, 13000000, 31),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '4-6 năm', 4, 6, 15000000, 32),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '6-8 năm', 6, 8, 17000000, 33),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', '8-10 năm', 8, 10, 19000000, 34),
    ('CCHNCT', 'Bác sỹ có CCHN (có thời hạn)', 'Từ 10 năm trở lên', 10, NULL, 21000000, 35),
    ('CK1', 'CK1', '0-2 năm', 0, 2, 20000000, 40),
    ('CK1', 'CK1', '2-4 năm', 2, 4, 22000000, 41),
    ('CK1', 'CK1', '4-6 năm', 4, 6, 24000000, 42),
    ('CK1', 'CK1', '6-8 năm', 6, 8, 26000000, 43),
    ('CK1', 'CK1', '8-10 năm', 8, 10, 28000000, 44),
    ('CK1', 'CK1', 'Từ 10 năm trở lên', 10, NULL, 30000000, 45),
    ('NOI_TRU', 'Nội trú', '0-2 năm', 0, 2, 40000000, 50),
    ('NOI_TRU', 'Nội trú', '2-4 năm', 2, 4, 44000000, 51),
    ('NOI_TRU', 'Nội trú', '4-6 năm', 4, 6, 48000000, 52),
    ('NOI_TRU', 'Nội trú', '6-8 năm', 6, 8, 52000000, 53),
    ('NOI_TRU', 'Nội trú', '8-10 năm', 8, 10, 56000000, 54),
    ('NOI_TRU', 'Nội trú', 'Từ 10 năm trở lên', 10, NULL, 60000000, 55);
