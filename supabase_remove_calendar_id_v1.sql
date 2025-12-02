-- Migration: Remove calendar_id from all calendar tables
-- Date: 2025-11-26
-- Purpose: Simplify calendar storage - use calendar_name as the primary identifier instead
-- Reasoning: calendar_id is device-specific and not portable. calendar_name is consistent across devices.

-- ============================================================================
-- 1. FAMILY_MEMBER_CALENDARS TABLE
-- ============================================================================

-- Drop the old index on calendar_id
drop index if exists public.idx_family_member_calendars_calendar_id;

-- Remove calendar_id column and update unique constraint
alter table public.family_member_calendars
drop constraint if exists unique_calendar_per_member;

alter table public.family_member_calendars
drop column if exists calendar_id;

-- Add new unique constraint on calendar_name instead
alter table public.family_member_calendars
add constraint unique_calendar_name_per_member
unique(family_member_id, calendar_name);

-- ============================================================================
-- 2. SHARED_CALENDARS TABLE
-- ============================================================================

-- Drop the old index on calendar_id
drop index if exists public.idx_shared_calendars_calendar_id;

-- Remove calendar_id column and update unique constraint
alter table public.shared_calendars
drop constraint if exists unique_shared_calendar_per_user;

alter table public.shared_calendars
drop column if exists calendar_id;

-- Add new unique constraint on calendar_name instead
alter table public.shared_calendars
add constraint unique_shared_calendar_name_per_user
unique(user_id, calendar_name);

-- ============================================================================
-- 3. PERSONAL_CALENDARS TABLE
-- ============================================================================

-- Remove calendar_id column and update unique constraint
alter table public.personal_calendars
drop constraint if exists "unique_calendar_per_user";

alter table public.personal_calendars
drop column if exists calendar_id;

-- Add new unique constraint on calendar_name instead
alter table public.personal_calendars
add constraint unique_personal_calendar_name_per_user
unique(user_id, calendar_name);

-- ============================================================================
-- 4. CALENDAR_EVENT_METADATA TABLE
-- ============================================================================

-- Drop the old indexes on calendar_id
drop index if exists public.idx_calendar_event_metadata_user_event;
drop index if exists public.idx_family_events_calendar_id;

-- Remove calendar_id column and update unique constraint
alter table public.calendar_event_metadata
drop constraint if exists unique_metadata_per_user_event;

alter table public.calendar_event_metadata
drop column if exists calendar_id;

-- Add new unique constraint using calendar_name instead
-- Note: We'll use event_identifier as unique key (which includes calendar info implicitly)
alter table public.calendar_event_metadata
add constraint unique_metadata_per_user_event
unique(user_id, event_identifier);

-- Recreate index for query performance (now on calendar_name if needed)
create index idx_calendar_event_metadata_user_event
on public.calendar_event_metadata(user_id, event_identifier);

-- ============================================================================
-- 5. FAMILY_EVENTS TABLE (if it exists and has calendar_id)
-- ============================================================================

-- Drop the old index on calendar_id
drop index if exists public.idx_family_events_calendar_id;

-- Remove calendar_id column if it exists
alter table public.family_events
drop column if exists calendar_id;

-- ============================================================================
-- Summary of Changes
-- ============================================================================
-- Removed:
--   - family_member_calendars.calendar_id
--   - shared_calendars.calendar_id
--   - personal_calendars.calendar_id
--   - calendar_event_metadata.calendar_id
--   - family_events.calendar_id
--
-- Updated Unique Constraints:
--   - family_member_calendars: now uses (family_member_id, calendar_name)
--   - shared_calendars: now uses (user_id, calendar_name)
--   - personal_calendars: now uses (user_id, calendar_name)
--   - calendar_event_metadata: now uses (user_id, event_identifier)
--
-- Calendar Matching:
--   - App will match calendars by calendar_name at runtime
--   - calendar_name comes from iOS Calendar (user-friendly, consistent across devices)
--   - No need to store device-specific calendar_id anymore
