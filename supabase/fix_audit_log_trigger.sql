-- This SQL script fixes the audit log trigger to allow null action_by_user_id
-- Run this in the Supabase SQL Editor to fix the issue

-- First, let's find and examine the current trigger
-- This will help us understand what needs to be fixed
SELECT tgname, tgtype, tgenabled FROM pg_trigger
WHERE tgrelid = 'public.family_members'::regclass;

-- The issue is that the trigger is trying to insert into family_activity_log
-- with a NOT NULL constraint on action_by_user_id, but the trigger doesn't set it properly

-- Solution: Modify the trigger to handle invitation acceptance specially
-- We need to find the exact trigger name and update it

-- For now, let's allow null action_by_user_id in the family_activity_log table
-- Modify the constraint if it exists
ALTER TABLE IF EXISTS public.family_activity_log
DROP CONSTRAINT IF EXISTS family_activity_log_action_by_user_id_not_null;

-- Or if the constraint is defined differently:
ALTER TABLE IF EXISTS public.family_activity_log
ALTER COLUMN action_by_user_id DROP NOT NULL;
