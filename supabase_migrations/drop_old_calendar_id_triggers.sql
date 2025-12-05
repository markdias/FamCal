-- Migration: Drop old triggers that reference calendar_id (removed column)
-- This fixes the error: "record 'new' has no field 'calendar_id'"
-- Run this BEFORE add_updated_at_timestamps.sql

-- ============================================
-- Drop old triggers that might reference calendar_id
-- ============================================

-- Drop any triggers on shared_calendars
DROP TRIGGER IF EXISTS set_calendar_id_shared_calendars ON shared_calendars;
DROP TRIGGER IF EXISTS update_calendar_id_shared_calendars ON shared_calendars;
DROP TRIGGER IF EXISTS sync_calendar_id_shared_calendars ON shared_calendars;

-- Drop any triggers on family_member_calendars
DROP TRIGGER IF EXISTS set_calendar_id_family_member_calendars ON family_member_calendars;
DROP TRIGGER IF EXISTS update_calendar_id_family_member_calendars ON family_member_calendars;
DROP TRIGGER IF EXISTS sync_calendar_id_family_member_calendars ON family_member_calendars;

-- Drop any triggers on personal_calendars
DROP TRIGGER IF EXISTS set_calendar_id_personal_calendars ON personal_calendars;
DROP TRIGGER IF EXISTS update_calendar_id_personal_calendars ON personal_calendars;
DROP TRIGGER IF EXISTS sync_calendar_id_personal_calendars ON personal_calendars;

-- Drop old functions that might reference calendar_id
DROP FUNCTION IF EXISTS update_shared_calendars_calendar_id();
DROP FUNCTION IF EXISTS update_family_member_calendars_calendar_id();
DROP FUNCTION IF EXISTS update_personal_calendars_calendar_id();
DROP FUNCTION IF EXISTS set_calendar_id();
DROP FUNCTION IF EXISTS sync_calendar_id();

-- ============================================
-- Verification: List all remaining triggers
-- ============================================
-- Uncomment to see what triggers still exist after cleanup:
-- SELECT trigger_name, event_object_table, action_statement
-- FROM information_schema.triggers
-- WHERE event_object_schema = 'public'
-- ORDER BY event_object_table, trigger_name;

-- Migration complete - old calendar_id triggers and functions dropped
