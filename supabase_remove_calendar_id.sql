-- Migration: Remove calendar_id from all calendar tables (v3 - final version)
-- Date: 2025-11-26
-- Purpose: Simplify calendar storage - use calendar_name as the primary identifier instead
-- Reasoning: calendar_id is device-specific and not portable. calendar_name is consistent across devices.
--
-- This version DEDUPLICATES records before adding the unique constraint
-- If a family member has the same calendar_name multiple times (from different devices),
-- we keep the most recent one and delete the others.
--
-- V3 Changes: Removed reference to family_events table (doesn't exist in this schema)

-- ============================================================================
-- 1. FAMILY_MEMBER_CALENDARS TABLE
-- ============================================================================

-- First, identify and delete duplicate calendar names per member (keep most recent)
-- Delete all but the most recent record for each (family_member_id, calendar_name) pair
DELETE FROM public.family_member_calendars
WHERE id NOT IN (
    SELECT DISTINCT ON (family_member_id, calendar_name) id
    FROM public.family_member_calendars
    ORDER BY family_member_id, calendar_name, created_at DESC
);

-- Now safe to drop the old index and constraint
drop index if exists public.idx_family_member_calendars_calendar_id;

alter table public.family_member_calendars
drop constraint if exists unique_calendar_per_member;

-- Remove calendar_id column
alter table public.family_member_calendars
drop column if exists calendar_id;

-- Add new unique constraint on calendar_name
alter table public.family_member_calendars
add constraint unique_calendar_name_per_member
unique(family_member_id, calendar_name);

-- ============================================================================
-- 2. SHARED_CALENDARS TABLE
-- ============================================================================

-- Delete duplicates (keep most recent)
DELETE FROM public.shared_calendars
WHERE id NOT IN (
    SELECT DISTINCT ON (user_id, calendar_name) id
    FROM public.shared_calendars
    ORDER BY user_id, calendar_name, created_at DESC
);

drop index if exists public.idx_shared_calendars_calendar_id;

alter table public.shared_calendars
drop constraint if exists unique_shared_calendar_per_user;

alter table public.shared_calendars
drop column if exists calendar_id;

alter table public.shared_calendars
add constraint unique_shared_calendar_name_per_user
unique(user_id, calendar_name);

-- ============================================================================
-- 3. PERSONAL_CALENDARS TABLE
-- ============================================================================

-- Delete duplicates (keep most recent)
DELETE FROM public.personal_calendars
WHERE id NOT IN (
    SELECT DISTINCT ON (user_id, calendar_name) id
    FROM public.personal_calendars
    ORDER BY user_id, calendar_name, created_at DESC
);

alter table public.personal_calendars
drop constraint if exists "unique_calendar_per_user";

alter table public.personal_calendars
drop column if exists calendar_id;

alter table public.personal_calendars
add constraint unique_personal_calendar_name_per_user
unique(user_id, calendar_name);

-- ============================================================================
-- 4. CALENDAR_EVENT_METADATA TABLE
-- ============================================================================

-- Delete duplicates (keep most recent)
DELETE FROM public.calendar_event_metadata
WHERE id NOT IN (
    SELECT DISTINCT ON (user_id, event_identifier) id
    FROM public.calendar_event_metadata
    ORDER BY user_id, event_identifier, created_at DESC
);

drop index if exists public.idx_calendar_event_metadata_user_event;

alter table public.calendar_event_metadata
drop constraint if exists unique_metadata_per_user_event;

alter table public.calendar_event_metadata
drop column if exists calendar_id;

alter table public.calendar_event_metadata
add constraint unique_metadata_per_user_event
unique(user_id, event_identifier);

create index idx_calendar_event_metadata_user_event
on public.calendar_event_metadata(user_id, event_identifier);

-- ============================================================================
-- Summary of Changes (V3)
-- ============================================================================
-- Deduplication:
--   - Removed duplicate (family_member_id, calendar_name) pairs, kept most recent
--   - Removed duplicate (user_id, calendar_name) pairs in shared_calendars
--   - Removed duplicate (user_id, event_identifier) pairs in event metadata
--
-- Removed:
--   - family_member_calendars.calendar_id
--   - shared_calendars.calendar_id
--   - personal_calendars.calendar_id
--   - calendar_event_metadata.calendar_id
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
