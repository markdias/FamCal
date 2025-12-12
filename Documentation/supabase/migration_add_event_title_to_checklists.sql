-- Migration: Add event_title column to event_checklists table
-- Description: Adds the event_title column to store event names with checklists
-- Date: 2025-12-12
-- Author: Claude Code

-- Add event_title column if it doesn't exist
ALTER TABLE public.event_checklists
ADD COLUMN IF NOT EXISTS event_title TEXT;

-- Add comment for documentation
COMMENT ON COLUMN public.event_checklists.event_title IS 'Title of the event associated with this checklist - used for cross-device display';

-- Verify the table has the new column
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'event_checklists'
ORDER BY ordinal_position;
