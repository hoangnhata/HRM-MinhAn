ALTER TABLE notifications
    ADD COLUMN related_announcement_id BIGINT NULL COMMENT 'Liên kết thông báo toàn viện' AFTER related_employee_id;

ALTER TABLE notifications
    ADD CONSTRAINT fk_notif_ann FOREIGN KEY (related_announcement_id) REFERENCES internal_announcements (id) ON DELETE SET NULL;

CREATE INDEX idx_notifications_announcement ON notifications (related_announcement_id);
