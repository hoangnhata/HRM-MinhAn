-- Mục thông báo (tab), ngày hiển thị, đính kèm
ALTER TABLE internal_announcements
    ADD COLUMN category VARCHAR(64) NOT NULL DEFAULT 'THONG_BAO_CHUNG' COMMENT 'Tab/mục thông báo' AFTER body,
    ADD COLUMN display_date DATE NULL COMMENT 'Ngày hiển thị (dòng đỏ)' AFTER category;

CREATE TABLE announcement_attachments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    announcement_id BIGINT NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    stored_path VARCHAR(500) NOT NULL,
    content_type VARCHAR(128),
    link_label VARCHAR(64) NOT NULL DEFAULT 'tại đây',
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ann_att_ann FOREIGN KEY (announcement_id) REFERENCES internal_announcements(id) ON DELETE CASCADE
);

CREATE INDEX idx_ann_att_announcement ON announcement_attachments (announcement_id);
