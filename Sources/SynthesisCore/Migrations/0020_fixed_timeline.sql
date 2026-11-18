-- Authored calendar time is independent of an event's prose label and list position.
CREATE UNIQUE INDEX timeline_event_world ON events(id, world_id);
CREATE TABLE timeline_calendars (
  id TEXT PRIMARY KEY NOT NULL,
  world_id TEXT NOT NULL UNIQUE REFERENCES worlds(id),
  name TEXT NOT NULL,
  month_lengths TEXT NOT NULL,
  days_per_week INTEGER NOT NULL CHECK(days_per_week BETWEEN 1 AND 100),
  hours_per_day INTEGER NOT NULL CHECK(hours_per_day BETWEEN 1 AND 100),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(id, world_id)
);
CREATE TABLE timeline_event_dates (
  id TEXT PRIMARY KEY NOT NULL,
  world_id TEXT NOT NULL REFERENCES worlds(id),
  event_id TEXT NOT NULL,
  calendar_id TEXT,
  year INTEGER,
  month INTEGER,
  day INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK(revision > 0),
  UNIQUE(world_id, event_id),
  FOREIGN KEY(event_id, world_id) REFERENCES events(id, world_id),
  FOREIGN KEY(calendar_id, world_id) REFERENCES timeline_calendars(id, world_id),
  CHECK(
    (calendar_id IS NULL AND year IS NULL AND month IS NULL AND day IS NULL)
    OR
    (calendar_id IS NOT NULL AND year IS NOT NULL AND month IS NOT NULL AND day IS NOT NULL)
  )
);

CREATE TRIGGER activity_timeline_event_dates_insert AFTER INSERT ON timeline_event_dates
WHEN NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at)
  VALUES(
    synthesis_uuid(),NEW.world_id,NEW.event_id,'event','updated',
    (SELECT title FROM events WHERE id=NEW.event_id AND world_id=NEW.world_id),
    'Calendar date set',strftime('%Y-%m-%dT%H:%M:%SZ','now')
  );
END;

CREATE TRIGGER activity_timeline_event_dates_update AFTER UPDATE ON timeline_event_dates
WHEN (OLD.calendar_id IS NOT NEW.calendar_id OR OLD.year IS NOT NEW.year
  OR OLD.month IS NOT NEW.month OR OLD.day IS NOT NEW.day)
  AND NOT EXISTS(SELECT 1 FROM activity_imports WHERE world_id=NEW.world_id)
BEGIN
  INSERT INTO world_activity(id,world_id,object_id,kind,action,title,detail,created_at)
  VALUES(
    synthesis_uuid(),NEW.world_id,NEW.event_id,'event','updated',
    (SELECT title FROM events WHERE id=NEW.event_id AND world_id=NEW.world_id),
    'Calendar date updated',strftime('%Y-%m-%dT%H:%M:%SZ','now')
  );
END;
