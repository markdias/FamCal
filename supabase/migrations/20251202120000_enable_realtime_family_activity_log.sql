-- Enable Realtime for family_activity_log table
-- This allows clients to subscribe to real-time changes to family activities

-- Add the family_activity_log table to the existing supabase_realtime publication
alter publication supabase_realtime add table public.family_activity_log;
