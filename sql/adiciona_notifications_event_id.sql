ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS event_id VARCHAR(255);

CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_event_id
    ON notifications (event_id) WHERE event_id IS NOT NULL;
