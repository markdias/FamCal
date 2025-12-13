-- Add schedule columns to family_members table
ALTER TABLE family_members
ADD COLUMN IF NOT EXISTS wake_time_hour INTEGER DEFAULT 7,
ADD COLUMN IF NOT EXISTS wake_time_minute INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS bed_time_hour INTEGER DEFAULT 22,
ADD COLUMN IF NOT EXISTS bed_time_minute INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS use_custom_schedule BOOLEAN DEFAULT FALSE;

-- Add comments for documentation
COMMENT ON COLUMN family_members.wake_time_hour IS 'Hour member wakes up (0-23), default 7am';
COMMENT ON COLUMN family_members.wake_time_minute IS 'Minute of wake time (0-59)';
COMMENT ON COLUMN family_members.bed_time_hour IS 'Hour member goes to bed (0-23), default 10pm';
COMMENT ON COLUMN family_members.bed_time_minute IS 'Minute of bed time (0-59)';
COMMENT ON COLUMN family_members.use_custom_schedule IS 'Flag to enable custom schedule times, defaults to false';
